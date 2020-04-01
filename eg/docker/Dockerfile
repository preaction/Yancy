FROM perl:5.30

COPY . /yancy
RUN cpanm /yancy \
    && rm -rf /yancy

CMD [ "./myapp.pl", "daemon" ]
