namespace=$1
sshkey=$2
touch namespace.last
lastNamespace=$(cat namespace.last)
lastNamespace=${lastNamespace:-next-gen-virt}
echo $sshkey
sshkey=${sshkey:-../demo.id_rsa.pub}
echo $sshkey
printf -v sshPubKey "%q" $(<$sshkey tr -d '\n' | base64 -w0)
if [ "x$namespace" == "x" ]
then
   read -p "What namespace name [$lastNamespace]? " namespace
fi
if [ -z "$namespace" ]
then
   namespace="$lastNamespace"
fi
echo "$namespace" > namespace.last
source ../subscription.txt
cat namespace.yaml.template | perl -pe "s/\{\{ namespace \}\}/$namespace/g" > $namespace.yaml
echo "---" >> $namespace.yaml
baseDomain=$(oc get  ingresses.config cluster  -o jsonpath='{.spec.appsDomain}')
cat elasticsearch.install.yaml.template kibana.yaml.template coordinate.yaml.template ubi9.yaml.template | \
  perl -pe "s/\{\{ namespace \}\}/$namespace/g" | \
  perl -pe "s/\{\{ baseDomain \}\}/$baseDomain/g" | \
  perl -pe "s/\{\{ subscriptionOrg \}\}/$subscriptionOrg/g" | \
  perl -pe "s/\{\{ subscriptionKey \}\}/$subscriptionKey/g" | \
  perl -MMIME::Base64 -pe "s/\{\{ sshPubKey \}\}/decode_base64('$sshPubKey')/ge" \
  >> $namespace.yaml
for name in es-master00 es-master01 es-master02; do
  cat elasticsearch.master.vm.yaml.template | \
      perl -pe "s/\{\{ name \}\}/$name/g" | \
      perl -pe "s/\{\{ namespace \}\}/$namespace/g" | \
      perl -pe "s/\{\{ baseDomain \}\}/$baseDomain/g" | \
      perl -MMIME::Base64 -pe "s/\{\{ sshPubKey \}\}/decode_base64('$sshPubKey')/ge" \
  >> $namespace.yaml
done
echo "# Apply yaml using:"
echo "oc apply -f $namespace.yaml"
echo "watch --color ./demo.sh"
