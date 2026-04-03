import os
import yaml
from core import process_repository

def main():
    """Main function to process repositories and generate schema and changes reports."""
    # Load config
    config_path = os.path.join(os.path.dirname(__file__), 'config', 'config.yaml')
    with open(config_path) as f:
        config = yaml.safe_load(f)

    github_token = os.environ.get('GITHUB_TOKEN')
    reports_dir = os.path.join(os.path.dirname(__file__), 'reports')
    os.makedirs(reports_dir, exist_ok=True)

    # Extract global settings
    owner = config.get("org", "pagopa")
    patterns = config.get("patterns", {})
    table_regex = patterns.get("table_regex", "")
    dao_pats = patterns.get("dao_patterns", [])
    ent_pats = patterns.get("entity_folder_patterns", [])

    # Process each repository
    for repo_name, repo_cfg in config.get('repos', {}).items():
        print(f"Processing: {repo_name}")
        process_repository(
            repo_name=repo_name,
            repo_cfg=repo_cfg,
            owner=owner,
            github_token=github_token,
            reports_dir=reports_dir,
            table_regex=table_regex,
            dao_patterns=dao_pats,
            entity_folder_patterns=ent_pats,
        )

if __name__ == "__main__":
    main()
