#!/bin/sh

# Argument pour l'exécution de config.txt
CONFIG_FILE=$1
# shellcheck source=config.txt
. "${CONFIG_FILE}"

# Authentification à GitHub
cat > ~/.netrc <<EOL
machine github.com
  login "${GH_USERNAME}"
  password "${GH_TOKEN}"
EOL

# Variable qui stocke une liste des repositories SVN(Ajouter les noms dans le config.txt->REPO_LIST)
if [ "$REPO_LIST" ]; then 
PROJECTS="$REPO_LIST"
else
# Si on souhaite récupérer tous les projets
PROJECTS=$(curl -s -u "$SVN_USERNAME":"$SVN2GIT_PASSWORD" "$URL_SVN"/ | awk -F'\>' '{print $3}' | sed 's/.\{4\}$//')
fi
CURRENT_PATH="$PWD"

export GH_TOKEN="$GH_TOKEN"
# Créer un fichier pour avoir la variable de GH_TOKEN
echo "$GH_TOKEN" > ghtoken.txt
# Connexion avec GitHub CLI à partir du fichier ghtoken.txt (refusé en simple variable)
gh auth login --with-token < ghtoken.txt
# Désactiver l'interaction de gh (ex: .gitignore, licence, template, etc)
gh config set prompt disabled
# Configurer git de manière globale avec ses identifiants
git config --global user.email "$GH_EMAIL"
git config --global user.name "$GH_USERNAME"

# Boucle pour installer toute la liste sauf le ".."
for project in $PROJECTS; do
  if [ "$project" = "." ] || [ "$project" = "<t" ]; then
    continue
  fi
  
  echo "$project"
  echo "$GH_TOKEN"

  # Créer le repository GitHub grâce à CLI de GitHub (brew install gh)
  if gh repo create "$project" --private -y; then
    mkdir -p "$project"
    echo "$PWD"
    cd "$project" || exit 1

    # Vérifier si le dépôt SVN existe avant de cloner
    SVN2GIT_PASSWORD="\"$SVN2GIT_PASSWORD\"" svn2git "$URL_SVN"/"$project" --username "$SVN_USERNAME" --trunk trunk --tags tags --nobranches

    echo "Branches list:"
    # Lister les branches, les tags, et le log
    git branch -l
    echo "Tags list:"
    git tag -l

    git branch -m master main

    # Ajouter le serveur distant, seulement s'il n'existe pas
    echo "Remote added"
    git remote add origin "$URL_GITHUB/$GH_USERNAME/$project.git"

    # Mettre à jour la balise <scm> dans le fichier pom.xml s'il existe
    if [ -f "pom.xml" ]; then
      # Appel de l'interpréteur Perl
      perl -i -pe "BEGIN{undef $/;} s|<scm>.*?</scm>|
      <scm>\n<url>scm:git:""$URL_GITHUB""/""$GH_USERNAME""/""$project"".git</url>
      \n<connection>scm:git:""$URL_GITHUB""/""$GH_USERNAME""/""$project"".git</connection>
      \n<developerConnection>scm:git:""$URL_GITHUB""/""$GH_USERNAME""/""$project"".git</developerConnection>
      \n<tag>HEAD</tag>\n</scm>|smg" pom.xml

      # Ajouter le plugin maven-release-plugin dans le fichier
      plugin_xml="<groupId>org.apache.maven.plugins</groupId>
          <artifactId>maven-release-plugin</artifactId>
          <version>2.5.3</version>
          <configuration>
              <tagNameFormat>${project}-@{project.version}</tagNameFormat>
              <localCheckout>true</localCheckout>
              <preparationGoals>clean install</preparationGoals>
              <checkModificationExcludes>
                  <checkModificationExclude>pom.xml</checkModificationExclude>
              </checkModificationExcludes>
          </configuration>"
      # Outil qui permet de modifier un fichier XML
      xmlstarlet ed -L -N a="http://maven.apache.org/POM/4.0.0" -s "/a:project/a:build/a:plugins" -t elem -n plugin -v "$plugin_xml" pom.xml
      # Modification de la syntaxe "chevron"
      sed -i "s/&lt;/</g" pom.xml 
      sed -i "s/&gt;/>/g" pom.xml

      # Mettre à jour et commit le pom.xml dans GitHub
      git add pom.xml
      git commit -m "edit pom.xml"
      echo "commit edit pom.xml"
      git push origin main

    else
      echo "pom.xml doesn't exist in ${project}"
    fi

    # Pousser la branche principale (main) vers GitHub
    git push origin main
    git push --all origin
    git push --tags origin

  else
    echo "${project} Already exist!"
  fi

  # Effacer tous les repositories pull en local une fois qu'ils sont push sur GitHub
  cd "$CURRENT_PATH" || exit
  rm -rf "$project"

done
