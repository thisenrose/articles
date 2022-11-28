FROM ruby:2.5-slim

WORKDIR /usr/src/app
COPY Gemfile Gemfile.lock ./
ENV BUNDLE_FROZEN=true

RUN gem install bundler -v 2.0.1 && \
    bundle config set deployment 'true' && \
    bundle config set without 'development test' && \
    bundle install

COPY . ./
CMD ["ruby", "./app.rb"]