FROM ruby:3.0-alpine3.15

LABEL maintainer = "marie mariebenitah1@gmail.com"

COPY svn2GitAllProjects.sh /

RUN apk update && apk add \
  curl \
  git \
  subversion \
  xmlstarlet \
  git-svn \
  libc6-compat \
  github-cli

RUN gem install svn2git3

RUN chmod +x /svn2GitAllProjects.sh

ENTRYPOINT [ "/svn2GitAllProjects.sh" ]
