FROM ruby:latest

RUN apt-get update -qq
RUN apt-get install -y wget fonts-liberation libasound2 libatk-bridge2.0-0 libatk1.0-0 libatspi2.0-0 libcups2 libdbus-1-3 libdrm2 libgbm1 libgtk-3-0 libnspr4 libnss3 libx11-xcb1 libxcomposite1 libxdamage1 libxfixes3 libxkbcommon0 libxrandr2 xdg-utils
RUN wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
RUN dpkg -i google-chrome-stable_current_amd64.deb
RUN gem install bundler

ENV APP_PATH /root
WORKDIR $APP_PATH
COPY Gemfile tmp $APP_PATH/
RUN bundle
COPY reg.rb $APP_PATH/

ENTRYPOINT [ "/bin/bash", "-l", "-c" ]
CMD [ "ruby reg.rb" ]