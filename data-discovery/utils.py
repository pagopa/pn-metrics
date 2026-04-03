import re

def extract_entity(content):
	"""
	Extract entity name and attributes from Java class content, if annotated with @DynamoDbBean.
    Params:
    - content: String content of a Java file.
	Output: Returns (class_name, attributes) or (None, None) if not a DynamoDB entity."""
	
	# Skip if not a DynamoDB entity
	if "@DynamoDbBean" not in content:
		return None, None
	# Extract class name and attributes
	class_match = re.search(r"class\s+(\w+)", content)
	if not class_match:
		return None, None
	class_name = class_match.group(1)
	attrs = {m.group(2): {"type": m.group(1)}
			 for m in re.finditer(r"private\s+([\w<>]+)\s+(\w+);", content)}
	# Identify custom DynamoDB names from @DynamoDbAttribute annotations on getters
	for m in re.finditer(r'@DynamoDbAttribute\s*\(\s*"(\w+)"\s*\)', content):
		getter = re.search(r"public\s+[\w<>]+\s+get(\w+)\(", content[m.end():])
		if getter:
			field = getter.group(1)[0].lower() + getter.group(1)[1:]
			if field in attrs:
				attrs[field]["dynamo_name"] = m.group(1)
	# Identify partition/sort keys
	for m in re.finditer(r"@(DynamoDbPartitionKey|DynamoDbSortKey)", content):
		fld = re.search(r"private\s+[\w<>]+\s+(\w+);", content[m.end():])
		if fld and fld.group(1) in attrs:
			attrs[fld.group(1)].setdefault("annotations", []).append(m.group(1))
	return class_name, attrs

def normalize_name(name):
	"""
	Normalize a name by removing common suffixes and converting to lowercase.
    Params:
    - name: The name to normalize.
    Output: Returns the normalized name.
	"""
	# Remove extensions and common suffixes, convert to lowercase for better matching
	name = re.sub(r"\.\w+$", "", name.lower())
	while True:
		stripped = re.sub(r"(entity|dao|dynamo|impl|pn|s)$", "", name)
		if stripped == name:
			break
		name = stripped
	return name
