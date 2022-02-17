ARG JELLYFIN_WEB_IMAGE=jellyfin/jellyfin-web
ARG JELLYFIN_WEB_IMAGE_TAG=10.7.7
ARG JELLYFIN_TIZEN_REPO=https://github.com/jellyfin/jellyfin-tizen.git
ARG JELLYFIN_TIZEN_BRANCH_OR_TAG=master

#
# JELLYFIN TIZEN BUILDER
#
FROM ${JELLYFIN_WEB_IMAGE:?}:${JELLYFIN_WEB_IMAGE_TAG:?} as jellyfin-tizen
ARG JELLYFIN_TIZEN_REPO
ARG JELLYFIN_TIZEN_BRANCH_OR_TAG
RUN git clone --depth 1 --branch ${JELLYFIN_TIZEN_BRANCH_OR_TAG:?} --single-branch -- ${JELLYFIN_TIZEN_REPO:?} /jellyfin-tizen \
  && cd /jellyfin-tizen \
  && JELLYFIN_WEB_DIR=/jellyfin-web yarn install

FROM spali/tizen-sdk-builder:latest as tizen-builder

#
# ACTUAL BUILD IMAGE
#
COPY --from=jellyfin-tizen --chown=tizen /jellyfin-tizen /jellyfin-tizen
COPY ./scripts /scripts
WORKDIR /jellyfin-tizen

ENV PATH="/scripts:${PATH}"

CMD [ "deploy.sh" ]
