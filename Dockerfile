FROM ruby:3.0

# RUN apt-get update && apt-get upgrade -y && apt-get install -y --no-install-recommends cron
# RUN touch /var/log/cron.log
COPY Gemfile* ./
RUN bundle install
# COPY crontab /etc/cron.d/cronjob
# RUN chmod 0644 /etc/cron.d/cronjob
COPY stalled_torrent_bot.rb .

# RUN crontab crontab

CMD ["ruby", "stalled_torrent_bot.rb"]
