import os
import json
import re

from datetime import datetime, timezone
from github_utils import GitHubRepoClient, walk_github_dir, download_properties_file
from utils import extract_entity, normalize_name


def add_entity_tree(table_name, ename, visited, tables, entities):
    """
    Recursively add an entity and all referenced entities to the table, avoiding cycles.
    Params:
    - table_name: The name of the table to add entities to.
    - ename: The name of the entity to add.
    - visited: A set of already visited entities to avoid cycles.
    - tables: The dictionary of tables.
    - entities: The dictionary of entities.
    Output:
    - Modifies the tables dictionary in-place by adding the entity and its referenced entities to the
    """
    # Recursively add entity and all referenced entities to the table, avoiding cycles
    if ename in visited or ename not in entities:
        return
    visited.add(ename)
    edata = entities[ename]
    if edata.get("table"):
        return
    tables[table_name]["entities"].append({
        "name": ename,
        "attributes": edata["attributes"],
        "file_path": edata["path"],
    })
    edata["table"] = table_name
    for attr in edata["attributes"].values():
        if attr.get("type") in entities:
            add_entity_tree(table_name, attr["type"], visited, tables, entities)


def match_dao_to_table(dao_path, dao_content, tables):
    """
    Match a DAO file to a table based on its content and name.
    Params:
    - dao_path: The path to the DAO file.
    - dao_content: The content of the DAO file.
    - tables: The dictionary of tables.
    Output:
    - Returns the name of the matched table or None if no match is found.
    """
    # First try: direct matches with config keys or table names
    for tname, tdata in tables.items():
        if tdata["config_key"] in dao_content:
            return tname
    for tname in tables:
        if tname in dao_content:
            return tname
    ndao = normalize_name(os.path.basename(dao_path))

    # Match DAO name to table name using normalization and substring checks (e.g. PaymentDao -> payment, payments, paymenttable)
    for tname in tables:
        nt = normalize_name(tname)
        if nt == ndao or nt in ndao or ndao in nt:
            return tname
    return None


def map_tables_to_entities(tables, dao_files, entities):
    """
    Map DAO files to tables and link all referenced entities to the corresponding table.
    Params:
    - tables: The dictionary of tables.
    - dao_files: A list of tuples containing DAO file paths and their content.
    - entities: The dictionary of entities.
    Output:
    - Modifies the tables dictionary in-place by linking entities to their corresponding tables.
    """
    # For each DAO, find the corresponding table and link all referenced entities to it
    for dao_path, dao_content in dao_files:

        table_name = match_dao_to_table(dao_path, dao_content, tables)
        if not table_name:
            continue
        if tables[table_name]["file_path"] is None:
            tables[table_name]["file_path"] = dao_path
        
        for match in re.finditer(r'([A-Z][A-Za-z0-9_]+)(?:\s|<|>)', dao_content):
            ename = match.group(1)
            if ename in entities:
                add_entity_tree(table_name, ename, set(), tables, entities)


def detect_changes(repo_name, reports_dir, new_schema, branch):
    """
    Detect changes in the schema for a given repository and generate a report.
    Params:
    - repo_name: The name of the repository.
    - reports_dir: The directory where reports are stored.
    - new_schema: The new schema to compare against the latest schema.
    - branch: The branch name of the repository.
    Output:
    - Generates a changes report if there are differences between the latest and new schema.
    """
    repo_dir = os.path.join(reports_dir, repo_name)
    os.makedirs(repo_dir, exist_ok=True)

    # Load latest schema
    schema_files = sorted(f for f in os.listdir(repo_dir) if f.startswith("schema_") and f.endswith(".json"))
    latest = None
    if schema_files:
        with open(os.path.join(repo_dir, schema_files[-1]), encoding="utf-8") as f:
            latest = json.load(f)

    # Skip if unchanged
    if latest and latest.get("tables") == new_schema.get("tables") and latest.get("orphan_entities") == new_schema.get("orphan_entities"):
        print(f"[SKIP] No changes for {repo_name}")
        return

    # Save new schema
    ts = new_schema["metadata"]["timestamp"]
    schema_path = os.path.join(repo_dir, f"schema_{ts}.json")
    with open(schema_path, "w", encoding="utf-8") as f:
        json.dump(new_schema, f, indent=2, ensure_ascii=False)
    print(f"[OK] Schema saved: {repo_name}/schema_{ts}.json")

    # Generate changes report only if a previous schema exists
    if latest is not None:
        def collect_attrs(schema):
            if schema is None:
                return {}
            out = {}
            for e in (e for t in schema.get("tables", {}).values() for e in t.get("entities", [])):
                out[e["name"]] = {k: v["type"] for k, v in e["attributes"].items()}
            for e in schema.get("orphan_entities", []):
                out[e["name"]] = {k: v["type"] for k, v in e["attributes"].items()}
            return out

        old, new = collect_attrs(latest), collect_attrs(new_schema)
        prev_ts = latest.get("metadata", {}).get("timestamp", "N/A")
        lines = [
            f"# Data Contract Change Report",
            f"Repository: {repo_name} ({branch})",
            f"Previous: {prev_ts} | Current: {ts}",
            "",
        ]
        sections = {"Added attributes": [], "Removed attributes": [], "Modified attributes": []}
        for name in sorted(set(old) | set(new)):
            oa, na = old.get(name, {}), new.get(name, {})
            for k in sorted(set(na) - set(oa)):
                sections["Added attributes"].append(f"  {name}.{k}: {na[k]}")
            for k in sorted(set(oa) - set(na)):
                sections["Removed attributes"].append(f"  {name}.{k}: {oa[k]}")
            for k in sorted(set(na) & set(oa)):
                if oa[k] != na[k]:
                    sections["Modified attributes"].append(f"  {name}.{k}: {oa[k]} -> {na[k]}")
        for title, items in sections.items():
            lines.append(f"## {title}")
            lines.append("\n".join(items) if items else "  (None)")
            lines.append("")

        changes_path = os.path.join(repo_dir, f"changes_{ts}.txt")
        with open(changes_path, "w", encoding="utf-8") as f:
            f.write("\n".join(lines))
        print(f"[OK] Changes saved: {repo_name}/changes_{ts}.txt")


def process_repository(repo_name, repo_cfg, owner, github_token, reports_dir,
                       table_regex, dao_patterns, entity_folder_patterns):
    """
    Process a repository to extract schema information and detect changes.
    Params:
    - repo_name: The name of the repository.
    - repo_cfg: The configuration dictionary for the repository.
    - owner: The owner of the repository.
    - github_token: The GitHub token for authentication.
    - reports_dir: The directory where reports are stored.
    - table_regex: The regex pattern to identify table names in DAO files.
    - dao_patterns: A list of patterns to identify DAO files.
    - entity_folder_patterns: A list of patterns to identify entity folders.
    Output:
    - Generates schema and changes reports for the repository.
    """
    # Setup GitHub client and get latest commit
    client = GitHubRepoClient(owner, repo_name, github_token)
    branch = repo_cfg.get("branch", "main")
    commit = client.get_commit_sha(branch)

    # Walk repository and collect Java files
    java_files = []
    walk_github_dir(client, repo_cfg["path"], java_files)

    # Download properties file if specified
    props = None
    if repo_cfg.get("properties_path"):
        props = download_properties_file(client, repo_cfg["properties_path"], java_files)

    # Extract tables from properties
    tables = {}
    for _, content in java_files:
        for m in re.finditer(table_regex, content):
            tname = m.group(2)
            if tname not in tables:
                tables[tname] = {"config_key": m.group(1), "file_path": None, "entities": []}

    # Map tables to entities
    dao_files, entities = [], {}
    for fpath, content in java_files:
        fname = os.path.basename(fpath)
        if any(fname.endswith(p.replace("*", "")) for p in dao_patterns):
            dao_files.append((fpath, content))
        if any(p.lower() in fpath.lower() for p in entity_folder_patterns):
            class_name, attrs = extract_entity(content)
            if class_name:
                entities[class_name] = {"attributes": attrs, "path": fpath}

    map_tables_to_entities(tables, dao_files, entities)

    # Identify orphan entities
    orphans = [
        {"name": n, "attributes": d["attributes"], "file_path": d["path"]}
        for n, d in entities.items() if not d.get("table")
    ]

    # Build output and detect changes
    schema = {
        "metadata": {
            "repository": repo_name,
            "branch": branch,
            "commit": commit,
            "timestamp": datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S"),
            "tables_count": len(tables),
            "entities_count": sum(len(t["entities"]) for t in tables.values()) + len(orphans),
        },
        "tables": tables,
        "orphan_entities": orphans,
    }
    detect_changes(repo_name, reports_dir, schema, branch)
