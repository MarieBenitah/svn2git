#!/bin/sh

CONFIG_FILE=$1
source $CONFIG_FILE

#Authentification à github
cat > ~/.netrc <<EOL
machine github.com
  login ${GH_USERNAME}
  password ${GH_TOKEN}
EOL

#Variable qui stocke la liste des repository svn
PROJECTS=$(curl -s -u $SVN_USERNAME:$SVN2GIT_PASSWORD $URL_SVN/ | awk -F'\>' '{print $3}' | sed 's/.\{4\}$//')
CURRENT_PATH=$PWD

export GH_TOKEN=$GH_TOKEN
#Créer un fichier pour avoir la variable de GH_TOKEN
echo $GH_TOKEN > ghtoken.txt
#Connection avec github cli à partir du fichier ghtoken.txt(refusé en simple variable)
gh auth login --with-token < ghtoken.txt
#Desctiver l'interaction de gh (ex: .gitignore, licence, template, etc)
gh config set prompt disabled
#Configurer git de manière globale
git config --global user.email $GH_EMAIL
git config --global user.name $GH_USERNAME
#Boucle pour installer toute la list sauf le ".."
for project in $PROJECTS; do
  if [ "$project" == '.' ] || [ "$project" == '<t' ] || [ "$project" == '' ]; then
    continue
  fi
  echo $project
  echo $GH_TOKEN
#Créer le repository gitHub grace à CLI de github(brew install gh)
  #gh repo delete $project --yes
if gh repo create $project --private -y; then
   mkdir -p $project
   cd $project || exit 1

# Vérifier si le dépôt SVN existe avant de cloner
SVN2GIT_PASSWORD="\"$SVN2GIT_PASSWORD\"" svn2git "$URL_SVN/$project" --username $SVN_USERNAME --trunk trunk --tags tags --nobranches

echo "Branches list:"
# Lister les branches, les tags, et le log
git branch -l
echo "Tags list:"
git tag -l

git branch -m master main

# Ajouter la télécommande origin, seulement si elle n'existe pas
echo 'Remote added'
git remote add $project "$URL_GITHUB/$GH_USERNAME/$project.git"

# Mettre à jour la balise <scm> dans le fichier pom.xml s'il existe
if [ -f "pom.xml" ]; then
    # Appel de l'interpréteur Perl
    perl -i -pe "BEGIN{undef $/;} s|<scm>.*?</scm>|
    <scm>\n<url>scm:git:$URL_GITHUB/$GH_USERNAME/$project.git</url>
    \n<connection>scm:git:$URL_GITHUB/$GH_USERNAME/$project.git</connection>
    \n<developerConnection>scm:git:$URL_GITHUB/$GH_USERNAME/$project.git</developerConnection>
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
    #Outil qui permet de modifier un fichier XML
    xmlstarlet ed -L -N a="http://maven.apache.org/POM/4.0.0" -s "/a:project/a:build/a:plugins" -t elem -n plugin -v "$plugin_xml" pom.xml
    # Modification de la syntaxe "chevron"
    sed -i "s/&lt;/</g" pom.xml 
    sed -i "s/&gt;/>/g" pom.xml
   
    #Mettre à jour et commit le pom.xml dans gitHub
    git add pom.xml
    git commit -m "edit pom.xml"
    echo "commit edit pom.xml"
    git push --set-upstream $project main

  else
    echo "pom.xml doesn't exist in $project"
  fi

# Pousser la branche principale (main) vers GitHub
git push --set-upstream $project main
git push --all $project
git push --tags $project
  
else
  echo "$project Already exist!"
fi

#Efface tous les repository pull en local une fois fois qu'ils sont push sur GitHub
cd $CURRENT_PATH
rm -rf $project

done