import base64
import requests

GITHUB_API = "https://api.github.com"


class GitHubRepoClient:
    """GitHub API client for repository access."""
    def __init__(self, owner, repo, token=None):
        self.owner = owner
        self.repo = repo
        self.session = requests.Session()
        if token:
            self.session.headers["Authorization"] = f"token {token}"
        self.session.headers["Accept"] = "application/vnd.github.v3+json"

    def _url(self, path):
        return f"{GITHUB_API}/repos/{self.owner}/{self.repo}/{path}"

    def list_files(self, dir_path):
        resp = self.session.get(self._url(f"contents/{dir_path}"))
        resp.raise_for_status()
        data = resp.json()
        return [data] if isinstance(data, dict) else data

    def download_file(self, file_path):
        resp = self.session.get(self._url(f"contents/{file_path}"))
        resp.raise_for_status()
        data = resp.json()
        if data.get('encoding') == 'base64':
            return base64.b64decode(data['content']).decode('utf-8')
        raise Exception(f"Unknown encoding: {file_path}")

    def get_commit_sha(self, branch="main"):
        resp = self.session.get(self._url(f"commits/{branch}"))
        resp.raise_for_status()
        return resp.json()['sha']


def walk_github_dir(client, path, java_files):
    """
    Recursively download .java files from a GitHub directory.
    Params:
        - client: An instance of GitHubRepoClient.
        - path: The path to the directory in the repository.
        - java_files: A list to store the downloaded .java files as tuples of (path, content).
    Output:
        - Modifies the java_files list in-place by adding tuples of (file_path, file_content) for each .java file found in the directory and its subdirectories.
    """
    path = path.replace('\\', '/')
    try:
        entries = client.list_files(path)
    except Exception as e:
        print(f"[WARN] Cannot read {path}: {e}")
        return
    for entry in entries:
        if entry['type'] == 'file' and entry['name'].endswith('.java'):
            try:
                java_files.append((entry['path'], client.download_file(entry['path'])))
            except Exception as e:
                print(f"[WARN] Cannot download {entry['path']}: {e}")
        elif entry['type'] == 'dir':
            walk_github_dir(client, entry['path'], java_files)


def download_properties_file(client, properties_path, java_files):
    """
    Download a properties file from the GitHub repository or return it from the cached java_files list.
    Params:
        - client: An instance of GitHubRepoClient.
        - properties_path: The path to the properties file in the repository.
        - java_files: A list of tuples containing file paths and their content.
    Output:
        - Returns the content of the properties file as a string, or None if it cannot be downloaded.
    """
    properties_path = properties_path.replace('\\', '/')
    for path, content in java_files:
        if path.endswith(properties_path):
            return content
    try:
        content = client.download_file(properties_path)
        java_files.append((properties_path, content))
        return content
    except Exception as e:
        print(f"[WARN] Cannot download properties: {e}")
        return None
