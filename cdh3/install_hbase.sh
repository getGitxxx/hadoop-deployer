#!/usr/bin/env bash
# coding=utf-8
# zhaigy@ucweb.com
# 2012-09

DIR=$(cd $(dirname $0);pwd)
. $DIR/PUB.sh

params()
{
  if [ -e ./install_env.sh ]; then
    . ./install_env.sh
    nodes;
  else
    :
  fi
}

# $0 host
deploy()
{
  echo ">> deploy $1";
  echo "DIR=$DIR;" > tmp.sh
  echo '
    set -e;
    cd $DIR;
    . ./PUB.sh;
    . ./profile_hbase.sh;
    . ./deploy_env.sh;
    tar -xzf tars/$HBASE_TAR -C $HOME;
    cd ..;
    ln -s ./$HBASE_VERSION $HBASE_HOME;
    cd $DIR;
  ' >> tmp.sh
  scp -q -P $SSH_PORT tmp.sh $USER@$1:/$DIR/
  ssh -p $SSH_PORT $USER@$1 sh $DIR/tmp.sh\; rm -f $DIR/tmp.sh
  rm -f tmp.sh
}

conf_hbase()
{
  echo ">> conf hbase"

  F1="s/<value"
  F2="\/value>/<value"
  F3="\/value>/"

  mkdir -p $HBASE_CONF_DIR
  cp hbaseconf/hbase-env.sh $HBASE_CONF_DIR;
  cp hbaseconf/hbase-site.xml $HBASE_CONF_DIR;

  HBASE_ENV="$HBASE_CONF_DIR/hbase-env.sh"
  HBASE="$HBASE_CONF_DIR/hbase-site.xml"
  REGIONSERVERS="$HBASE_CONF_DIR/regionservers"
  BACKUP_MASTERS="$HBASE_CONF_DIR/backup-masters"

  sed -r "s#^export HBASE_SSH_OPTS.*#export HBASE_SSH_OPTS=\"-p $SSH_PORT\"#" -i $HBASE_ENV;

  var_die HBASE_ZOOKEEPER_QUORUM;
  var_die HBASE_ROOTDIR;
  sed -r "$F1>hbase.zookeeper.quorum<$F2>$HBASE_ZOOKEEPER_QUORUM<$F3" -i $HBASE;
  sed -r "s#<value>hbase.rootdir<\/value>#<value>$HBASE_ROOTDIR<\/value>#" -i $HBASE;
  sed -r "s#<value>hbase.tmp.dir<\/value>#<value>$HBASE_TMP_DIR<\/value>#" -i $HBASE;
  echo $NODE_HOSTS > $REGIONSERVERS;
  echo ${DN//$NN/} > $BACKUP_MASTERS;

  echo ">> rsync hbase configuration";
  rsync_all "$HBASE_CONF_DIR/*" $HBASE_CONF_DIR/;
  rsync_all "$HBASE_BIN/*" $HBASE_BIN/;
}

#==========
# main $*;
#==========
cd $DIR
[ -f logs/hadoop_ok ] || die "must install hadoop first"
[ -f logs/hbase_ok ] && die "hbase is installed" ||:;
show_head;
params;
download
#rsync_all $DIR $HOME
toDIR=`cd $DIR/..; pwd`
rsync_all $DIR $toDIR
for s in $NODE_HOSTS; do
  [ -f "logs/deploy_hbase_${s}_ok" ] && echo " $s already install hbase" && continue 
  deploy $s; 
  touch "logs/deploy_hbase_${s}_ok"
done
. $DEPLOYER_HOME/profile_hbase.sh;
. $DEPLOYER_HOME/deploy_env.sh
conf_hbase;
touch logs/hbase_ok
echo ">> OK"
cd $OLD_DIR

