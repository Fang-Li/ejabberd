#! /bin/sh
PORT=6281
JAVA_HOME=/app/java/jdk1.7.0_45
set -x
cp="target/classes"
for i in `ls -1 target/lib/*.jar`; do
       cp=${cp}:./$i
done
$JAVA_HOME/bin/java -cp ${cp} -Xms3000m -Xmx3000m com.cc14514.Main ${PORT} &
