# get a pre-configure Spack
FROM {{ spack_base_image }}

# setup a default installation path
RUN (echo "config:" \
&&   echo "  install_tree:" \
&&   echo "    root: /opt/software") > .spack/config.yaml

# install default packages. Note: only Spack build-dependencies
RUN apt-get -yqq update && apt-get -yqq install python3 python3-dev python3-pip automake pkg-config \
&& update-alternatives --install /usr/bin/python python /usr/bin/python3 20 \
&& rm -rf /var/lib/apt/lists/*

RUN (echo "spec:" \
&&   echo "  - tar" \
&&   echo "  - automake" \
&&   echo "  - autoconf" \
&&   echo "  - pkg-config" \
&&   echo "  - python3" \
&&   echo "  - m4" \
&&   echo "  - xz" \
&&   echo "  - perl") > .spack/scm-spec.yaml

# speed-up Spack installation process by generate packages.yaml file
# filled with pre-installed default packages from previous steps (see above) 
RUN git clone https://github.com/ravil-mobile/spack-complete-me.git \
&& pip3 install wheel \
&& pip3 install -r spack-complete-me/requirements.txt \
&& pip3 install -e ./spack-complete-me \
&& python3 spack-complete-me/scm -H > .spack/packages.yaml

# install compiler
RUN spack install {{ compiler }} arch={{ arch_family }} +piclibs \
&& spack compiler add $(spack location -i {{ compiler }}) \
&& spack gc -y

# set installed compiler as an external package and leave compiler meta data
RUN compiler_suite=$(echo {{ compiler }} | sed -E 's/(\w*)@.*/\1/') \
&& compiler_spec=$(spack find -v {{ compiler }} | tail -1) \
&& compiler_path=$(spack location -i {{ compiler }} | tr -d '\n') \
&& echo $compiler_path > /opt/software/compiler_path \
&& (echo "  ${compiler_suite}:" \
&&  echo "    buildable: false" \
&&  echo "    externals:" \
&&  echo "    - spec: ${compiler_spec}" \
&&  echo "      prefix: ${compiler_path}") >> .spack/packages.yaml

# install seissol spack-installation scripts
RUN mkdir spack_support spack_support/packages /workspace
ADD ./spack/repo.yaml spack_support
ADD ./spack/packages ./spack_support/packages
RUN spack repo add spack_support

#NOTE: the current version of spack doesn't allow to install a compiler
# from a speck and immediately use it. Therefore, we create a pre-build
# spack image where we explicitely install and add a compiler first.
# Additionally, we copy and add SeisSol Spack installation scripts
# which we're going to use in the next building step