FROM perl:5.30

# First install prereqs, so this can be cached
RUN mkdir /yancy
COPY ./cpanfile /yancy/cpanfile
RUN cpanm --installdeps /yancy

# Then install the rest of Yancy
COPY ./* /yancy/
RUN cpanm /yancy \
    && rm -rf /yancy

CMD [ "./myapp.pl", "daemon" ]
