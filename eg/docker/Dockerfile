FROM perl:5.30

# First install prereqs, so this can be cached
RUN mkdir /yancy
COPY ./cpanfile /yancy/cpanfile
RUN cpanm --installdeps --notest /yancy

# Then install the rest of Yancy
COPY ./ /yancy/
RUN cpanm --notest -v /yancy \
    && rm -rf /yancy

CMD [ "./myapp.pl", "daemon" ]
