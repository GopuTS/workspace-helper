#!/bin/bash

featureModulesFile=~/easy/FeatureModules.txt
workSpace=~/workspace-sts/universe

cd $workSpace

moduleRegx="*-model* *client* *-service* platform-*"
stashSuffix="easyWSSwitch"

modules=()

function garbageCollect {
	for m in $moduleRegx; do
	  cd $m
	  printf "In $m \n"
	  git gc
	  cd ..
	done
}

function setFeatureModules {
	while read -r moduleName ; do
		if [[ "$moduleName" != *"#"* ]]; then
			modules+=($moduleName)
		fi
	done < "$featureModulesFile"
	if [[ ${#modules[@]} < 1 ]]; then
		printf "please set the modules in $featureModulesFile \n"
	fi	
}

function setAllModules {
	for f in $moduleRegx; do
		modules+=($f)
	done
}

function isDirty {
	if [[  -z "$(git status --porcelain)" ]]; then
		return 1;
	else
		return 0;

	fi
}

# isDirty

# if [[ $? == 0 ]]; then
# 	echo "WorkingCopy is dirty"
# fi

function isBranchExists {
	# module=$1
	# repositoryTemplate="git@git.unigroupinc.com:universe/$module.git"
	branch=$1
	repository=$(git config --get remote.origin.url)
	returnValue=$(git ls-remote $repository $branch)
	if [[ -n $returnValue ]]; then
		return 0
	else
		return 1	
	fi
}

# isBranchExists "gis-service" "feature/PROF-530-ba_flow_update_for_inter_realm"
# echo "$?"
dirtyModules=()
function getDirtyModules {
	for f in $moduleRegx; do
	  cd $f
	  isDirty
	  if [[ $? == 0 ]]; then
			dirtyModules+=($f)
	  fi  
	  cd ..
	done
}

function switchBranch {
	destinationBranch=$1
	for f in $moduleRegx; do
		echo "-------------"		
		printf "$f:\n"
		cd $f
		switchToBranch="develop"
		isBranchExists $destinationBranch
		if [[ $? == 0 ]]; then
			switchToBranch=$destinationBranch
		fi
		currentBranchName=$(git symbolic-ref --short HEAD)
		stashMessage="$currentBranchName-$stashSuffix"
		if [[ isDirty ]]; then
			git stash save --include-untracked "$stashMessage"
		fi
		git checkout $switchToBranch
		stashMessage="$switchToBranch-$stashSuffix"
		stashToPop=$(git stash list | grep $stashMessage | grep -o stash@\{.\})
		if [[ ! -z $stashToPop ]]; then
			git stash pop $stashToPop
		fi
		echo "-------------"			  
	  cd ..
	done
}

function pull {
	for f in ${modules[@]}; do
		cd $f
		echo "-------------"
		printf "$f:\n"
		currentBranchName=$(git symbolic-ref --short HEAD)
		stashMessage="$currentBranchName-$stashSuffix"
		if [[ isDirty ]]; then
			git stash save --include-untracked "$stashMessage"
		fi
		git pull
		stashToPop=$(git stash list | grep $stashMessage | grep -o stash@\{.\})
		if [[ ! -z $stashToPop ]]; then
			git stash pop $stashToPop
		fi
		echo "-------------"
		cd ..
	done
}

function push {
	for f in ${modules[@]}; do
		cd $f
		git push
		cd ..
	done
}

function validateForDirtyModules {
		isStrictMode=$1
		if [[ $isStrictMode == true ]]; then
			getDirtyModules
			if [[ ${#dirtyModules[@]} > 0 ]]; then
				printf "Running in strict mode. Dirty modules are not allowed:\n"
				echo "${dirtyModules[@]}"
				printf "\n"
			exit 1
			fi
			printf "All modules are clean!\n"
		fi
}

function startFeature {
	featureName=$1
	baseBranchName=$2
	for m in ${modules[@]}; do
		cd $m
		git flow feature start $featureName $baseBranchName
		cd ..
	done
}

function finishFeature {
	featureName=$1
	for m in ${modules[@]}; do
		cd $m
		git flow feature finish $featureName
		cd ..
	done
}

if [[ "$1" == "ic" || "$1" == "isClean" ]]; then
	getDirtyModules
	if [[ ${#dirtyModules[@]} > 0 ]]; then
		echo "Oops! There are dirty modules: ${dirtyModules[@]}"
	else
		echo "Hurray! All modules are clean! No uncommited changes."
	fi
elif [[ "$1" == "s" || "$1" == "switch" ]]; then
	echo "s / switch"
	branch=$2
	if [[ -z $branch ]]; then
		echo "One more argument needed: <destination branch name>"
		exit 1
	fi
	isStrictMode=${3-true}
	validateForDirtyModules $isStrictMode
	switchBranch $branch
elif [[ "$1" == "pl" || "$1" == "pull" ]]; then
	whichModules=${2-f}
	isStrictMode=${3-true}
	validateForDirtyModules $isStrictMode
	if [[ $whichModules == "all" ]]; then
		setAllModules
	else
		setFeatureModules
	fi
	pull
elif [[ "$1" == "ps" || "$1" == "push" ]]; then
	#statements
	whichModules=${2-f}
	isStrictMode=${3-true}
	validateForDirtyModules $isStrictMode
	if [[ $whichModules == "all" ]]; then
		setAllModules
	else
		setFeatureModules
	fi
	push
elif [[ "$1" == "sf" || "$1" == "startFeature" ]]; then
	featureName=$2
	if [[ -z $featureName ]]; then
		printf "featureName is mandatory to start a feature \n"
		exit 1
	fi
	baseBranchName=${3-develop}
	printf "base branch: $baseBranchName \n"
	setFeatureModules
	startFeature $featureName $baseBranchName
elif [[ "$1" == "ff" || "$1" == "finishFeature" ]]; then
	featureName=$2
	if [[ -z $featureName ]]; then
		printf "featureName is mandatory to finish a feature \n"
		exit 1
	fi
	setFeatureModules	
	finishFeature $featureName
		#statements	
			#statements		
# elif [[ $1 == 1 ]]; then
# 		setFeatureModules
# 		echo "${modules[@]}"
# 		printf "\n"
elif [[ "$1" == "gc" || "$1" == "garbageCollect" ]]; then
	garbageCollect
else
	printf "*********************************************\n"
	printf "Please provide one of the below arguments:\n"

	printf "ic/isClean\n"
	
	printf "s/switch\n"
	printf "s <branch name> <isStrictMode>[*true|false]"
	
	printf "pl/pull\n"
	printf "pl/pull <feature or all>[*f|all] <isStrictMode>[*true|false]\n"

	printf "ps/push\n"
	printf "ps/push <feature or all>[*f|all] <isStrictMode>[*true|false]\n"	

	printf "sf/StartFeature\n"
	printf "sf/StartFeature <feature branch name> <base branch>\n"

	printf "ff/finishFeature\n"

	printf "gc/garbageCollect\n"
	printf "gc"

	printf "*********************************************\n"
fi