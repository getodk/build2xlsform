FROM node:16.14.2
LABEL author="ODK"
LABEL maintainer="ODK Build maintainers"
LABEL description="Generate an XLSForm from an ODK Build Xform"

WORKDIR /srv/odkbuild2xlsform
COPY . .
RUN make
EXPOSE 8686
CMD ["node", "lib/server.js"]
