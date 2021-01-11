# ARG BASE_IMAGE_VERSION=2.2.2-py3
# FROM tensorflow/tensorflow:${BASE_IMAGE_VERSION}
FROM python:3.6

# Install required dependencies for this project
RUN apt update && \
	apt install -y python3-opencv && \
	pip3 install --use-feature=2020-resolver tensorflow keras keras-rl gym numpy \
		matplotlib pillow pygame dill opencv-python gym[atari] && \
	mkdir /code
WORKDIR /code
CMD [ "/bin/bash" ]
