FROM ruby:2.5
LABEL maintainer "Sinlead <opensource@sinlead.com>"
ENV LANG="C.UTF-8" APP_PATH="/usr/src/gcp-ip-blocker/"
WORKDIR $APP_PATH
COPY Gemfile Gemfile.lock ./
RUN bundle install
COPY blocker.rb ./
CMD ["ruby", "blocker.rb"]
