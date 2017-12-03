HOME ?=/home/${USER}
ifeq ($(shell which spark-submit),)
     SPARK_HOME ?= /home/y/share/spark
else
     SPARK_HOME ?=$(shell which spark-submit 2>&1 | sed 's/\/bin\/spark-submit//g')
endif
CAFFE_ON_SPARK ?=$(shell pwd)
LD_LIBRARY_PATH ?=/home/y/lib64:/home/y/lib64/mkl/intel64:/usr/local/cuda/
LD_LIBRARY_PATH2=${LD_LIBRARY_PATH}:${CAFFE_ON_SPARK}/caffe-public/distribute/lib:${CAFFE_ON_SPARK}/caffe-distri/distribute/lib:/usr/lib64:/lib64 
DYLD_LIBRARY_PATH ?=/home/y/lib64:/home/y/lib64/mkl/intel64:/usr/local/cuda/lib
DYLD_LIBRARY_PATH2=${DYLD_LIBRARY_PATH}:${CAFFE_ON_SPARK}/caffe-public/distribute/lib:${CAFFE_ON_SPARK}/caffe-distri/distribute/lib:/usr/lib64:/lib64

SPARK_VERSION ?= $(shell ${SPARK_HOME}/bin/spark-submit --version 2>&1 | grep version | awk '{print $$5}' | cut -d'.' -f1)
ifeq (${SPARK_VERSION}, 2)
MVN_FLAGS += -Dspark2
endif

lmdbjni_VERSION ?= 0.4.6
MVN_FLAGS += -Dlmdbjni.version=$(lmdbjni_VERSION)

protobuf_VERSION ?= $(shell python -c "import google.protobuf as pb; print pb.__version__")
MVN_FLAGS += -Dprotobuf.version=$(protobuf_VERSION)

ARCH ?= $(shell uname -m)

JARS := ${CAFFE_ON_SPARK}/caffe-distri/target/caffe-distri-0.1-SNAPSHOT.jar
JARS += ${CAFFE_ON_SPARK}/caffe-distri/target/caffe-distri-0.1-SNAPSHOT-jar-with-dependencies.jar
JARS += ${CAFFE_ON_SPARK}/caffe-grid/target/caffe-grid-0.1-SNAPSHOT.jar
JARS += ${CAFFE_ON_SPARK}/caffe-grid/target/caffe-grid-0.1-SNAPSHOT-jar-with-dependencies.jar

build:
	$(MAKE) proto -C ./caffe-public
	$(MAKE) -j4 -e distribute -C ./caffe-public
	rm -f $(JARS)
	export LD_LIBRARY_PATH="${LD_LIBRARY_PATH2}"; \
	  GLOG_minloglevel=1 mvn $(MVN_FLAGS) -B package -DskipTests
ifeq ($(ARCH),ppc64le)
	echo "substituting jar"
	mkdir -p META-INF/native/linux64
	cp liblmdbjni.so META-INF/native/linux64/liblmdbjni.so
	jar -uf caffe-grid/target/caffe-grid-0.1-SNAPSHOT-jar-with-dependencies.jar META-INF/
endif
	jar -xvf caffe-grid/target/caffe-grid-0.1-SNAPSHOT-jar-with-dependencies.jar META-INF/native/linux64/liblmdbjni.so
	mv META-INF/native/linux64/liblmdbjni.so ${CAFFE_ON_SPARK}/caffe-distri/distribute/lib
	#${CAFFE_ON_SPARK}/scripts/setup-mnist.sh
	#export LD_LIBRARY_PATH="${LD_LIBRARY_PATH2}"; GLOG_minloglevel=1 mvn $(MVN_FLAGS) -B test
	cd ${CAFFE_ON_SPARK}/caffe-grid/src/main/python/; zip -r caffeonsparkpythonapi  *; cd ${CAFFE_ON_SPARK}/caffe-public/python/; zip -ur ${CAFFE_ON_SPARK}/caffe-grid/src/main/python/caffeonsparkpythonapi.zip *; cd - ; mv caffeonsparkpythonapi.zip ${CAFFE_ON_SPARK}/caffe-grid/target/; cd ${CAFFE_ON_SPARK}
	#export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}; export SPARK_HOME=${SPARK_HOME};GLOG_minloglevel=1 ${CAFFE_ON_SPARK}/caffe-grid/src/test/python/PythonTest.sh

buildosx:
	cd caffe-public; make proto; make -j4 -e distribute; cd ..
	export DYLD_LIBRARY_PATH="${DYLD_LIBRARY_PATH2}"; GLOG_minloglevel=1 mvn $(MVN_FLAGS) -B package -DskipTests
	jar -xvf caffe-grid/target/caffe-grid-0.1-SNAPSHOT-jar-with-dependencies.jar META-INF/native/osx64/liblmdbjni.jnilib
	mv META-INF/native/osx64/liblmdbjni.jnilib ${CAFFE_ON_SPARK}/caffe-distri/distribute/lib
	${CAFFE_ON_SPARK}/scripts/setup-mnist.sh
	export LD_LIBRARY_PATH="${DYLD_LIBRARY_PATH2}"; GLOG_minloglevel=1 mvn $(MVN_FLAGS) -B test
	cd ${CAFFE_ON_SPARK}/caffe-grid/src/main/python/; zip -r caffeonsparkpythonapi  *; cd ${CAFFE_ON_SPARK}/caffe-public/python/; zip -ur ${CAFFE_ON_SPARK}/caffe-grid/src/main/python/caffeonsparkpythonapi.zip *; cd -; mv caffeonsparkpythonapi.zip ${CAFFE_ON_SPARK}/caffe-grid/target/; cd ${CAFFE_ON_SPARK}
	cd ${CAFFE_ON_SPARK}/caffe-grid/src/main/python/; zip -r caffeonsparkpythonapi *; mv caffeonsparkpythonapi.zip ${CAFFE_ON_SPARK}/caffe-grid/target/; cd ${CAFFE_ON_SPARK}
	export DYLD_LIBRARY_PATH=${DYLD_LIBRARY_PATH}; export SPARK_HOME=${SPARK_HOME};GLOG_minloglevel=1 ${CAFFE_ON_SPARK}/caffe-grid/src/test/python/PythonTest.sh

update:
	git submodule init
	git submodule update --force
	git submodule foreach --recursive git clean -dfx

doc: 
	scaladoc -cp caffe-grid/target/caffe-grid-0.1-SNAPSHOT-jar-with-dependencies.jar:${HOME}/.m2/repository/org/apache/spark/spark-core_2.10/1.6.0/spark-core_2.10-1.6.0.jar:${HOME}/.m2/repository/org/apache/spark/spark-sql_2.10/1.6.0/spark-sql_2.10-1.6.0.jar:${HOME}/.m2/repository/org/apache/spark/spark-mllib_2.10/1.6.0/spark-mllib_2.10-1.6.0.jar:${HOME}/.m2/repository/org/apache/spark/spark-catalyst_2.10/1.6.0/spark-catalyst_2.10-1.6.0.jar:$(shell hadoop classpath)  -d scala_doc caffe-grid/src/main/scala/com/yahoo/ml/caffe/*.scala
	cd python_doc; make html; cd ..

gh-pages: 
	rm -rf scala_doc
	git checkout gh-pages scala_doc

clean: 
	#cd caffe-public; make clean; cd ..
	cd caffe-distri; make clean; cd ..
	mvn $(MVN_FLAGS) clean

ALL: build
