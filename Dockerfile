FROM perl:5

RUN cpanm Modern::Perl \
          JSON::Parse \
          LWP::UserAgent \
          Config::Simple
VOLUME /data
WORKDIR /data

CMD perl /data/HumbleBundle.pl
