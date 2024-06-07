# Dockerized SVN to GitHub Migration Script
This script is designed to migrate SVN to GitHub repositories in private. It uses the following tools:

- **curl** to retrieve the list of SVN repositories
- **git** for version control and pushing to GitHub
- **subversion** for interacting with the SVN repositories
- **xmlstarlet** to update the SCM section in the pom.xml file (if it exists)
- **git-svn** for cloning SVN repositories as Git repositories
- **libc6-compat** for compatibility with older librairies
- **github CLI** to create and push Git repositories to GitHub
- **svn2git3(Ruby version)** to convert SVN repositories to Git


## How to Use
The script uses a configuration file (config.txt) to define the necessary environment variables.
1. Create a configuration file named `config.txt` with the following content:
```
SVN_USERNAME=<your_svn_username>
SVN2GIT_PASSWORD=<your_svn_password>
URL_SVN=<your_svn_url>
GH_USERNAME=<your_github_username>
GH_EMAIL=<your_github_email>
GH_TOKEN=<your_github_token>
```
Replace `<your_svn_username>`, `<your_svn_password>`, `<your_svn_url>`, `<your_github_username>`, `<your_github_email>`, and `<your_github_token>` with your own credentials.

2. Build the Docker image:
```
docker build -t svn2github .
```
3. Run the Docker container:
```
docker run -d -v $(pwd)/config.txt:/config.txt svn2github
```
This command will run the container in the background and mount the config.txt file in the container.

## Limitations
This script has been tested with simple SVN repositories that use the standard trunk, tags, and branches layout. It may not work correctly with more complex SVN repositories or those that use a non-standard layout.

Additionally, this script does not migrate SVN authorization to GitHub. You may need to manually configure GitHub repository permissions after the migration.

This Dockerfile uses the **ruby:3.0-alpine3.15** image as a base and installs the necessary tools and dependencies using **apk**. It then copies the **svn2Github.sh** script to the image, sets the script as the entrypoint, and grants execute permissions to the script.

