#!/bin/bash

#BADGE (BlAst based Diagnostic Gene findEr) - check_BADGE
#Version 1.0
#Copyright (C) 2015 Juergen Behr & Andreas Geissler

#This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version. This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details. You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
#Contact information: juergen.behr@wzw.tum.de

#Quick start: 1.Extract BADGE to your home directory (or any other desired directory)
#             2.Check the "installation" from terminal by executing the check_BADGE.sh script within the BADGE/t-data directory (terminal / command line)

#This script is checking your BADGE-installation using test data - execute from t-data directory using your terminal and the command "./check_BADGE"

#TODO: if you are using this script for the first time, while you already used BADGE for your own data - remove genomes / orfs directories and set BADGE to default settings!!!!

#check if genomes / orfs directories are present in BADGE directory or if a log-file from a previous testrun exists - if not proceed with checking BADGE

if [[ ! -d ../genomes && ! -d ../orfs && ! -e diff.log ]]
	then
	
	#copy test data into BADGE directory
	
	cp -R genomes orfs ../
	
	#execute BADGE with test-data
	sed -i "s/clean_up=true/clean_up=false/g" ../BADGE.sh
	sed -i "s/protein_level_clean_up=false/protein_level_clean_up=true/g" ../BADGE.sh	
	../BADGE.sh
	
	#copy and rename actual BADGE output (actual status) and supplied BADGE output (target status) into tmp directories for comparison - remove files and directories which are not wanted or necessary for comparison
	
	#create tmp directories
	
	mkdir comp_tmp_target_status
	mkdir comp_tmp_actual_status

	#copy actual and target output into tmp directories

	cp -rf out_target/* comp_tmp_target_status/
	cp -rf ../{A_vs_B,A_vs_C,B_vs_A,B_vs_C,C_vs_A,C_vs_B} comp_tmp_actual_status/

	#move all files in from output directories (e.g. A_vs_B) in parent directories (comp_tmp_actual_status / comp_tmp_target_status)

	for D in `find comp_tmp_target_status  -mindepth 1 -maxdepth 1 -type d`
		do	
		front_string=$(basename $D)
		mv -f $D/Step_*/* $D/
		rm -fr $D/Step_*/ $D/blast_dbs
		cd $D
		for f in *.*
			do 
			mv $f ../${front_string}_${f}
		done
		cd ../../
	done

	for D in `find comp_tmp_actual_status  -mindepth 1 -maxdepth 1 -type d`
		do	
		front_string=$(basename $D)
		mv -f $D/Step_*/* $D/
		rm -fr $D/Step_*/ $D/blast_dbs
		cd $D
		for f in *.*
			do 
			mv $f ../${front_string}_${f}
		done
		cd ../../
	done
	
	#remove files and directories which are not wanted or necessary for comparison
	
	rm -fr comp_tmp_target_status/{A_vs_B,A_vs_C,B_vs_A,B_vs_C,C_vs_A,C_vs_B}
	rm -fr comp_tmp_target_status/*.alignment comp_tmp_target_status/*.settings
	rm -fr comp_tmp_actual_status/{A_vs_B,A_vs_C,B_vs_A,B_vs_C,C_vs_A,C_vs_B}
	rm -fr comp_tmp_actual_status/*.alignment comp_tmp_actual_status/*.settings

	#compare actual output to target output - report if identical or not

	#compare all relevant files from tmp directories and write any differences into a log-file

	for i in `find comp_tmp_target_status -type f | cut -d "/" -f2`
		do
    		diffout=`diff <(cat comp_tmp_actual_status/$i | sort)  <(cat comp_tmp_target_status/$i | sort)`

    		if [ ! -z "$diffout" ]
			then
        		echo $i "	comp_tmp_actual_status != comp_tmp_target_status" >> diff.log
        		diff <(cat comp_tmp_actual_status/$i | sort)  <(cat comp_tmp_target_status/$i | sort) >> diff.log
    		fi
    	diffout=""
	done

	#check if diff.log exists - if not report that installation is correct	
	
	if [ ! -e diff.log ]
		then
		echo
		echo "The output produced by your BADGE installation is correct - BADGE installation was successful"
		echo
		echo
	else
		platform=`uname`
		if [[ $platform == 'Darwin' ]]
			then
			#get system information from MAC
			cat /etc/*release >> OS_and_progs.txt		
			uname -rm >> OS_and_progs.txt
			echo >> OS_and_progs.txt
			../bin/grep --version | ../bin/grep -e "grep " >> OS_and_progs.txt
			awk --version | grep -e "Awk " >> OS_and_progs.txt
			sort --version | grep -e "sort " >> OS_and_progs.txt
					
		else

			#get system information		

			cat /etc/*release >> OS_and_progs.txt
			echo >> OS_and_progs.txt		
			uname -rm >> OS_and_progs.txt
			echo >> OS_and_progs.txt
			grep --version | grep -e "grep " >> OS_and_progs.txt
			awk --version | grep -e "Awk " >> OS_and_progs.txt
			awk -W version | grep -e "mawk" >> OS_and_progs.txt
			sort --version | grep -e "sort " >> OS_and_progs.txt
			uniq --version | grep -e "uniq " >> OS_and_progs.txt
			cat --version | grep -e "cat " >> OS_and_progs.txt
			cut --version | grep -e "cut " >> OS_and_progs.txt
			xargs --version | grep -e "xargs " >> OS_and_progs.txt
			sed --version | grep -e "sed " >> OS_and_progs.txt
			wc --version | grep -e "wc " >> OS_and_progs.txt
			find --version | grep -e "find " >> OS_and_progs.txt	
			date --version | grep -e "date " >> OS_and_progs.txt
			cp --version | grep -e "cp " >> OS_and_progs.txt
			mv --version | grep -e "mv " >> OS_and_progs.txt
			rm --version | grep -e "rm " >> OS_and_progs.txt	
			mkdir --version | grep -e "mkdir " >> OS_and_progs.txt
			pr --version | grep -e "pr " >> OS_and_progs.txt
			
		fi
		
		#compress files with tar to fail_report

		mkdir fail_report
		cp -f OS_and_progs.txt diff.log fail_report/	
		cp -rf ../{A_vs_B,A_vs_C,B_vs_A,B_vs_C,C_vs_A,C_vs_B} fail_report/
		tar -czf fail_report.tar.gz fail_report/
		rm -rf fail_report/ OS_and_progs.txt diff.log

		
		echo
		echo "The output produced by your BADGE installation is not correct!" 
		echo
		echo
		echo
		echo "First check BADGE settings, then BADGE installation and if your operating system is supported"
		echo
		echo
		echo
		echo "Check the diff.log file for details  - differences between the target status (output supplied by us) and the actual status (output produced by you)"
		echo
		echo
		echo
		echo "If your problem remains - send fail_report.tar.gz to support and wait for an answer"
		echo

	fi

	#clean up - if you want to have a closer look to the actual output of your BADGE installation using the test data > set clean_up_test to false
	
	clean_up_test=true
	if $clean_up_test
		then
		rm -rf 	comp_tmp_target_status comp_tmp_actual_status out_actual_tmp ../*_vs_* ../genomes ../orfs
	fi
	sed -i "s/clean_up=false/clean_up=true/g" ../BADGE.sh
else

	echo
	echo "Warning - BADGE directory contains directories genomes / orfs or diff.log is present - (re)move before using the test data!"
	echo
	exit 0

fi


