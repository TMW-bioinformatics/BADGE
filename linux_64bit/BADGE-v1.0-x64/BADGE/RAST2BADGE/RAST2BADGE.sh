#!/bin/bash

#BADGE (BlAst based Diagnostic Gene findEr) - RAST2BADGE
#Version 1.0
#Copyright (C) 2015 Juergen Behr & Andreas Geissler

#This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version. This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details. You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
#Contact information: juergen.behr@wzw.tum.de

#RAST2BADGE takes gff files and fna files, created by RAST (http://rast.nmpdr.org/) and creates fasta files with a modified annotation, improved in human readability and better for running BADGE

#Quick start: 1.Download gff and fna files from RAST
#             2.Place them into the BADGE/RAST2BADGE directory
#             3.Rename them as you like (species_strain) but identically (e.g. E_coli_K12.gff / E_coli_K12.fna) - this way RAST2BADGE will include these information into the annotation
#             4.Execute the RAST2BADGE.sh script within the directory (terminal / command line - "./RAST2BADGE")
#             4.A file for each pair of gff /fna with the same basename but with the ending ".fasta" will be created and is ready for use with BADGE

#start time

stime=$(date +"%s")

#start of annotation loop 

for i in *.fna
	do

	#get basename off fna / gff	
	
	basefna=$(basename "${i%.*}")
	echo	
	echo "Annotating $basefna"
	echo
	
	#extract new IDs (annotation / header) from gff file	
	
	while read line
		do
			if [[ "$line" == *.peg.* ]]
				then
					ID=`echo $line | awk '{print $9}' | awk '{ gsub("ID=","");gsub(";Name=","\t");print $1 }' | awk 2>/dev/null '{gsub("[\\|'\''()=/,.:]+", "_"); print}'`
					annotation=`echo $line | sed "s/^.*Name=//"`
					contig=`echo $line | awk '{print $1 " " $4 "-" $5}'`
					echo ">"$basefna""_""$ID" "$annotation" "$contig >> $basefna"_new_IDs_tmp.annotation"
				fi
	done < $basefna".gff"

	#create array with new IDs

	IFS=$'\n' read -d '' -r -a new_ID < $basefna"_new_IDs_tmp.annotation"
	n=0

	#replace old IDs with new IDs

	while read old_line
		do
    			if [[ "$old_line" == ">"* ]]
				then
        			echo ${new_ID[n]} >> $basefna".fasta"
        			((n=n+1))
    			else
				echo $old_line >> $basefna".fasta"

			fi

	done < $basefna".fna"

	#clean up - remove temporary files

	rm -f $basefna"_new_IDs_tmp.annotation"
done

#end time

etime=$(date +"%s") 

#calculate the elapsed time

elapsed_time=$(($etime-$stime))

echo "Elapsed processor time:" $(($elapsed_time / 60))"min and" $(($elapsed_time % 60))"sec"
