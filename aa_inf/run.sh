#! /bin/sh
PORT=7777
JAVA_HOME=/app/java/jdk1.7.0_25
set -x
cp="target/classes"
for i in `ls -1 target/lib/*.jar`; do
       cp=${cp}:./$i
done
$JAVA_HOME/bin/java -cp ${cp} -Xms1024m -Xmx1024m com.cc14514.Main ${PORT} &
