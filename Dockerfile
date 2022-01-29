FROM node:10.19.0
LABEL author="GetODK Inc."
LABEL maintainer="ODK Build maintainers"
LABEL description="ODK build2xlsform, a Xforms to XLSForm converter"

WORKDIR /srv/odkbuild2xlsform
COPY . .
RUN make
EXPOSE 8686
CMD ["node", "lib/server.js"]