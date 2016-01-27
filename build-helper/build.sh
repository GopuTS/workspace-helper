#!/bin/bash

modules=()

function setModuleList {
	while read -r moduleName; 
	do
		if [[ "$moduleName" != *"#"* ]]; 
		then
			modules+=($moduleName)
		fi
	done < "modules.txt"
}

setModuleList

echo "modules -> ${modules[@]}"

cd ~/workspace-sts/universe

# function install {
# 	return 0
# }
function install {
	cd $1
	mvn clean install -Dmaven.test.skip=true
	returnValue=$?
	echo "return value = $returnValue"
	cd ..
	echo "Done installation"
	return $returnValue
}
failedModules=()
successModules=()
i=0
j=0
for module in "${modules[@]}";
do
	echo "$module"
	install $module
	returnValue=$?
	if [[ $returnValue != 0 ]]; then
		failedModules[$((i++))]=$module
	else
		successModules[$((j++))]=$module
	fi
done
echo "failedModules -> ${failedModules[@]}"
echo "successModules -> ${successModules[@]}"


