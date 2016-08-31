#!/bin/bash

#annotation_equalizer
#Version 1.0
#Copyright (C) 2015 Juergen Behr & Andreas Geissler

#GPL3
#This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version. This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details. You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.

#Contact information: juergen.behr@wzw.tum.de

#Quick start: 1.Create directories BADGE/genomes & BADGE/orfs
#             2.Create directories corresponding to your groups within BADGE/genomes & BADGE/orfs (e.g. BADGE/genomes/A & BADGE/orfs/A as well as BADGE/genomes/B & BADGE/orfs/B)
#             3.Place files with genomes and orfs (identically named) into corresponding directories
#             4.Execute the annotation_equalizer script within the directory (terminal / command line - "./annotation_equalizer")
#             6.You will find your equalized orf files in BADGE/annotation_equalizer/Xtra, the original files in BADGE/annotation_equalizer/raw
#	      7.Copy the genomes and orfs folders from BADGE/annotation_equalizer/orfs/Xtra to the BADGE directory in order to use them for BADGE
#For detailed description see the manual


#TODO: Settings - adjust your settings if desired TODO


#DC-MEGABLAST settings - default 95 / 0.000000000000001 / 0.95  - NOTE: These settings determine what you consider as "identical" / same orfs!! 
dc_megablast_perc_identity_cut=95
dc_megablast_e_value=0.000000000000001
dc_megablast_within_group_qscov=0.95

#Number of parallel blast processes - default 1
num_blast_proc=1


##################################################################################################################################################################################################

#helper functions
get_fasta () {

#USAGE: get_fasta input.identifier blastdb output.fasta

$blastbin_path/blastdbcmd -db $2 -entry_batch $1 >> $3

}

##################################################################################################################################################################################################

#start of function - time

stime=$(date +"%s");

#get annotation_equalizer directory

AE_path=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
cd $AE_path

#check if input is available and if output area has been cleared

if ! [[ -d ../genomes && ../orfs ]]
	then
	echo
	echo "Warning - no input available!"
	echo
	exit 1	
fi

if (( $(ls | grep -vcE "annotation_equalizer.sh|previous_run_") > 0 ))
	then
	prev_run_dir="previous_run_"$(date +%Y%m%d_%H%M%S)
	mkdir $prev_run_dir
	mv `ls | grep -vE "annotation_equalizer.sh|previous_run_"` ./$prev_run_dir 2>/dev/null
fi

##################################################################################################################################################################################################


#create databases

echo
echo
echo
echo -e "\e[34m#######################################################################\e[0m"

echo -e "\e[103m\e[1mSearch for inconsistent annotation\e[0m"
echo -e "\e[34m#######################################################################\e[0m"
echo
echo
echo -e "\e[34m#######################################################################\e[0m"
echo -ne "\e[1mCreating BLAST databases\e[0m\r"


#move sequence data to annotation_equalizer directory

mv  ../genomes ./
mv  ../orfs ./

#define paths

blastbin_path=../bin
genomes_path=./genomes
orfs_path=./orfs

#get types genomes dir and make list

type_list=""
for i in $(ls -d ./genomes/*)
	do
	types=`basename "$i"`
	type_list=$type_list" "$types
done


#make blast dbs for orfs and genomes of all members and each type

for type in $type_list
	do
	for i in $orfs_path/$type/*.fasta
		do
		dbname=$(basename "$i" .fasta)
		echo $dbname >> $type"_members.txt"
		cat $i | awk '{gsub("[\\|'\''()=/,.:]+", "_"); print}' > $orfs_path/$type/$dbname".tmp"
		mv -f $orfs_path/$type/$dbname".tmp" $orfs_path/$type/$dbname".fasta"
		$blastbin_path/makeblastdb -in $i -input_type fasta -dbtype nucl -title $dbname"_orfs" -parse_seqids -out $dbname"_orfs" -logfile $dbname"_orfs_db.log"
		$blastbin_path/blastdbcmd -db $dbname"_orfs" -entry all -outfmt "%i" | cut -d "|" -f 2 > $dbname"_orfs.identifier"
	done

	cat $orfs_path/$type/*.fasta > $type"_orfs.fasta"
	$blastbin_path/makeblastdb -in $type"_orfs.fasta" -input_type fasta -dbtype nucl -title $type"_orfs" -parse_seqids -out $type"_orfs" -logfile $type"_orfs_db.log"

	for i in $genomes_path/$type/*.fasta
		do
		dbname=$(basename "$i" .fasta)
		cat $i | awk '{gsub("[\\|'\''()=/,.:]+", "_"); print}' > $genomes_path/$type/$dbname".tmp"
		mv -f $genomes_path/$type/$dbname".tmp" $genomes_path/$type/$dbname".fasta"
		$blastbin_path/makeblastdb -in $i -input_type fasta -dbtype nucl -title $dbname"_genomes" -parse_seqids -out $dbname"_genomes" -logfile $dbname"_genomes_db.log"
	done

done

##################################################################################################################################################################################################

#create sequence files with potential non or differently annotated orfs for each member - containing only all non redundant orfs from all OTHER members of a particular type

	echo
	echo -e "\e[34m#######################################################################\e[0m"
	echo -e "\e[1mStep 1 of 4:  Create non-redundant query files to search for alternative annotations\e[0m"
	echo

#generate non redundant single line orf list (column 1: sequence; column 2: header), remove completely identical sequences within a type and create a sequence file for each member with all sequences from its type but not containing its own entries / sequences

for type in $type_list
	do
	cat $type"_orfs.fasta" | awk '/^>/ {printf("\n%s\n",$0);next; } { printf("%s",$0);}  END {printf("\n");}' | awk 'NF' | awk '!(NR%2){print$0"\t"p}{p=$0}' | sort -k1 | awk '!($1 in a){a[$1]; print}' > "Step1_1_"$type"_orfs_single_line.txt"

	#remove all member sequences from type sequences in order to create quey
	
	while read member
		do
		grep -F -w -v -f $member"_orfs.identifier" "Step1_1_"$type"_orfs_single_line.txt" > "Step1_2_"$type"_orfs_witout_"$member"_orfs_single_line.txt"	
		awk '{print$2"\n"$1}' "Step1_2_"$type"_orfs_witout_"$member"_orfs_single_line.txt" > "Step1_2_"$type"_orfs_witout_"$member"_orfs_single_line.fasta"	
	done <  $type"_members.txt"
done


##################################################################################################################################################################################################

#identify annotated orfs - remove entries from query files with correspoding annotation / gene in another member of the same type - idenify "identical" annotated orfs with small differences (default 95 % piden / 95 % coverage)

	echo
	echo -e "\e[34m#######################################################################\e[0m"
	echo -e "\e[1mStep 2 of 4:  Find sequences which are annotated consistently within members of each type\e[0m"
	echo

#blast query files vs member orfs and identify those which are annotated consistently

for type in $type_list
	do

	num_members=`cat $type"_members.txt" | wc -l`
	if [[ $num_members -gt 1 ]]
	then
		while read member
			do
			cat "Step1_2_"$type"_orfs_witout_"$member"_orfs_single_line.fasta" > split_input.fasta
			seq_num=`grep -c ">" split_input.fasta`
			if [[ $num_blast_proc -gt $seq_num ]]
				then
				num_blast_proc=1
			fi
			split_at_num=$(( seq_num/num_blast_proc ))
			awk -v split_at_num=$split_at_num -v fastafilebasename="seq_split" 'BEGIN {n_seq=0;} /^>/ {if(n_seq%split_at_num==0){fastafile=sprintf(fastafilebasename"%d.fasta",n_seq);} print >> fastafile; n_seq++; next;} { print >> fastafile; }' < split_input.fasta
	
			#perform blast
	
			query_num=1
			for queryfiles in ./seq_split*".fasta"
				do
				$blastbin_path/blastn -db $member"_orfs" -query $queryfiles -outfmt "6 qseqid sseqid qlen slen pident length evalue" -max_target_seqs 500 -num_threads 4 -task dc-megablast | awk -v dc_megablast_within_group_qscov=$dc_megablast_within_group_qscov -v dc_megablast_perc_identity_cut=$dc_megablast_perc_identity_cut -v dc_megablast_e_value=$dc_megablast_e_value '{if ($6/$3 >= dc_megablast_within_group_qscov && $6/$4 >= dc_megablast_within_group_qscov && $5 >= dc_megablast_perc_identity_cut && $7 <= dc_megablast_e_value) print $0}' > "seq_split_"$query_num".blast" &
				query_num=$(( query_num+1 ))	
			done
			wait
			cat "seq_split_"*".blast" > "Step2_1_"$member"_filtered_"$type"_orfs_vs_"$member"_orfs.blast"
			cat "Step2_1_"$member"_filtered_"$type"_orfs_vs_"$member"_orfs.blast" | awk '{ print $1 }' | sort -u > "Step2_2_"$member"_filtered_"$type"_orfs_vs_"$member"_orfs.identifier"
	
			#filter blast output - discard consistent annotated orfs
	
			grep -F -w -v -f "Step2_2_"$member"_filtered_"$type"_orfs_vs_"$member"_orfs.identifier" "Step1_2_"$type"_orfs_witout_"$member"_orfs_single_line.txt" > "Step2_3_"$member"_filtered_"$type"_orfs_single_line.txt"
			awk '{print$2"\n"$1}' "Step2_3_"$member"_filtered_"$type"_orfs_single_line.txt" > "Step2_3_"$member"_filtered_"$type"_orfs.fasta"
			cat "Step2_3_"$member"_filtered_"$type"_orfs.fasta"	| grep ">" | cut -d ">" -f 2 | sort -u > "Step2_4_"$member"_filtered_"$type"_orfs.identifier"	
			
			#clean up 
	
			rm -f "seq_split_"*".blast"  "seq_split"*".fasta" split_input.fasta "Step1_2_"$type"_orfs_witout_"$member"_orfs_single_line.txt" "Step2_3_"$member"_filtered_"$type"_orfs_single_line.txt"
	
		done <  $type"_members.txt"
	fi
done

##################################################################################################################################################################################################

#identify non or alternative annotated orfs - identify all orfs in each member which are not or differently annotated in other members of each type (default 95 % pident / 95 % coverage)

	echo
	echo -e "\e[34m#######################################################################\e[0m"
	echo -e "\e[1mStep 3 of 4:  Find non- or differently annotated orfs for each member within each type\e[0m"
	echo

#blast remaining query files (orfs which where not annotated consistently) vs member genomes and identify those which are not or differently annotated

for type in $type_list
	do
		
	mkdir -p Xtra/orfs/$type
	
	num_members=`cat $type"_members.txt" | wc -l`
	if [[ $num_members -gt 1 ]]
	then
		while read member
			do
	
			#prepare for blast - identify all type orfs non annotated in member
	
			cat "Step2_3_"$member"_filtered_"$type"_orfs.fasta" > split_input.fasta
			seq_num=`grep -c ">" split_input.fasta`
			if [[ $num_blast_proc -gt $seq_num ]]
				then
				num_blast_proc=1
			fi
			split_at_num=$(( seq_num/num_blast_proc ))
			awk -v split_at_num=$split_at_num -v fastafilebasename="seq_split" 'BEGIN {n_seq=0;} /^>/ {if(n_seq%split_at_num==0){fastafile=sprintf(fastafilebasename"%d.fasta",n_seq);} print >> fastafile; n_seq++; next;} { print >> fastafile; }' < split_input.fasta
	
			#perform blast
	
			query_num=1
			for queryfiles in ./seq_split*".fasta"
				do
				$blastbin_path/blastn -db $member"_genomes" -query $queryfiles -outfmt "6 qseqid sseqid qlen pident length evalue qstart qend sstart send" -max_target_seqs 500 -num_threads 4 -task dc-megablast | awk -v dc_megablast_within_group_qscov=$dc_megablast_within_group_qscov -v dc_megablast_perc_identity_cut=$dc_megablast_perc_identity_cut -v dc_megablast_e_value=$dc_megablast_e_value '{if ($5/$3 >= dc_megablast_within_group_qscov && $4 >= dc_megablast_perc_identity_cut && $6 <= dc_megablast_e_value) print $0}' > "seq_split_"$query_num".blast" &
				query_num=$(( query_num+1 ))	
			done
			wait
			cat "seq_split_"*".blast" > "Step3_1_"$type"_orfs_vs_"$member"_genome.blast" 
			cat "Step3_1_"$type"_orfs_vs_"$member"_genome.blast" | awk '{ print $1 }' | sort -u > "Step3_2_"$type"_orfs_vs_"$member"_genome.identifier"
	

			#clean up split files
	
			rm -f "seq_split_"*".blast"  "seq_split"*".fasta" split_input.fasta
	
			#extraxt non or differently annotated orfs
		
			get_fasta "Step3_2_"$type"_orfs_vs_"$member"_genome.identifier" $type"_orfs" "Step3_4_non_annotated_"$type"_orfs_in_"$member".fasta"
			$blastbin_path/makeblastdb -in "Step3_4_non_annotated_"$type"_orfs_in_"$member".fasta" -input_type fasta -dbtype nucl -title $member"_vs_"$type"_genomes" -parse_seqids -out $member"_vs_"$type"_genomes" -logfile $$member"_vs_"$type"_genomes_db.log"
	
			#prepare for blast - remove redundant non annotated orfs
	
			cat "Step3_4_non_annotated_"$type"_orfs_in_"$member".fasta" > split_input.fasta
			seq_num=`grep -c ">" split_input.fasta`
			if [[ $num_blast_proc -gt $seq_num ]]
				then
				num_blast_proc=1
			fi
			split_at_num=$(( seq_num/num_blast_proc ))
			awk -v split_at_num=$split_at_num -v fastafilebasename="seq_split" 'BEGIN {n_seq=0;} /^>/ {if(n_seq%split_at_num==0){fastafile=sprintf(fastafilebasename"%d.fasta",n_seq);} print >> fastafile; n_seq++; next;} { print >> fastafile; }' < split_input.fasta
		
			#perform blast
	
			query_num=1
			for queryfiles in ./seq_split*".fasta"
				do	
				$blastbin_path/blastn -db $member"_vs_"$type"_genomes" -query $queryfiles -outfmt "6 qseqid sseqid qlen slen pident length evalue" -max_target_seqs 500 -num_threads 4 -task dc-megablast | awk -v dc_megablast_within_group_qscov=$dc_megablast_within_group_qscov -v dc_megablast_perc_identity_cut=$dc_megablast_perc_identity_cut -v dc_megablast_e_value=$dc_megablast_e_value '{if ($6/$3 >= dc_megablast_within_group_qscov && $6/$4 >= dc_megablast_within_group_qscov && $5 >= dc_megablast_perc_identity_cut && $7 <= dc_megablast_e_value) print $0}' > "seq_split_"$query_num".blast" &
				query_num=$(( query_num+1 ))	
			done
			wait
			cat "seq_split_"*".blast" > "Step3_5_all_vs_all_non_annotated_"$type"_orfs_in_"$member"_genome.blast"
	
			#clean up split files
	
			rm -f "seq_split_"*".blast"  "seq_split"*".fasta" split_input.fasta	
		
			#remove blast lcl tag
	
			cat "Step3_5_all_vs_all_non_annotated_"$type"_orfs_in_"$member"_genome.blast" | cut -d "|" -f 2 > "Step3_5_all_vs_all_non_annotated_"$type"_orfs_in_"$member"_genome_tmp.blast"
			mv -f "Step3_5_all_vs_all_non_annotated_"$type"_orfs_in_"$member"_genome_tmp.blast" "Step3_5_all_vs_all_non_annotated_"$type"_orfs_in_"$member"_genome.blast"
	
			#put all sequence IDs matching the same DMG sequence in one line (not ordered yet) 
	
			cat "Step3_5_all_vs_all_non_annotated_"$type"_orfs_in_"$member"_genome.blast" | awk '{
			c++
			if ($1 != prev && c != 1) {
			print prev " " outstring;
			outstring="";
			if ($1 != $2) {
			outstring=outstring " " $2;
			};
			}
			else {
			if ($1 != $2) {
			outstring=outstring " " $2;
			};
			}; 
			prev=$1}
			END{print prev " " outstring;}' > "Step3_6_non_annotated_in_"$member"_tmp1.identifier"
	
			#sort sequence IDs in all lines
	
			while read line
				do
  				#echo $ID
				echo $line | xargs -n1 | sort -u | xargs >> "Step3_6_non_annotated_in_"$member"_tmp2.identifier"
			done < "Step3_6_non_annotated_in_"$member"_tmp1.identifier"
	
			#sort DMG IDs and remove duplicates - create files with all IDs of a particular DMG per line (ordered)
	
			sort "Step3_6_non_annotated_in_"$member"_tmp2.identifier" | uniq -c >> "Step3_6_non_annotated_in_"$member"_tmp3.identifier"
	
			removed_DMGs=0
			while read new_line
				do
				words_in_line=`echo $new_line | wc -w`
				DMGs_in_line=`echo $new_line | awk '{print $1;}'`
				count=$((words_in_line-DMGs_in_line))	
				if [[ $count -eq 1 ]]
					then
					echo $new_line | cut -d " " -f2- >> "Step3_6_non_annotated_in_"$member"_tmp4.identifier"
				else 
					removed_DMGs=$(( removed_DMGs+1 ))
				fi
  		
			done < "Step3_6_non_annotated_in_"$member"_tmp3.identifier"
	
			cat "Step3_6_non_annotated_in_"$member"_tmp4.identifier" | awk '{print $1}' >> "Step3_6_non_annotated_in_"$member".identifier"

##################################################################################################################################################################################################

#Add non- or differently annotated sequences to single genomes (members)

		echo
		echo -e "\e[34m#######################################################################\e[0m"
		echo -e "\e[1mStep 4 of 4:  Add additional non- or differently annotated sequences to $member\e[0m"
		echo
	
			#extract non annotated sequences and add them, in frame, to member orfs file
		
		while read ID
			do
	
			#get coordinates and orientation
		
			reverse_seq=false
			coord_blast=`grep -F -w -m 1 $ID "Step3_1_"$type"_orfs_vs_"$member"_genome.blast"`
			header=`echo $coord_blast | awk '{ print $1}'`
			contig=`echo $coord_blast | awk '{ print $2}'`
			start=`echo $coord_blast | awk '{ print $9}'`
			stop=`echo $coord_blast | awk '{ print $10}'`
			start_query=`echo $coord_blast | awk '{ print $7}'`
	
			#prepare for sequence extraction
	
			if [ $start -gt $stop ]
				then
				tmp=$stop
				stop=$start
				start=$tmp
				reverse_seq=true
			fi
	
			#check if sequence is in frame
	
			if [ $start_query -gt 1 ]
				then
	
				frame_state=$(( (start_query - 1) % 3 ))
				
				if [ $frame_state -gt 0 ]
					then
					frame_corr=$(( 3 - frame_state ))	
				fi
	
						
				if $reverse_seq	
					then
					stop=$(( stop - frame_corr ))	
	
				else
					
					start=$(( start + frame_corr ))
	
				fi
					
			
			fi
	
			#create identifier / header
			
			new_header=`$blastbin_path/blastdbcmd -db $type"_orfs" -dbtype nucl -entry $header  -outfmt "%a %t"`		
			echo ">XTRA_$member"_"$new_header	$contig	$start $stop" >> "Step4_1_non_annotated_sequences_in_"$member".annotation"
	
			#extract in frame sequences, ready for translation
	
			if $reverse_seq
				then

				#extract sequence and convert to one line fasta				
				
				$blastbin_path/blastdbcmd -db $member"_genomes" -dbtype nucl -entry $contig -range $start-$stop -outfmt "%f" |awk 'BEGIN{RS=">";FS="\n"}NR>1{seq="";for (i=2;i<=NF;i++) seq=seq""$i; print ">"$1"\n"seq}'  > "Step4_2_tmp_single_line.fasta"

				#reverse complement

				while read old_line
					do
    					if [[ "$old_line" == ">"* ]]
						then
						echo $old_line >> "Step4_2_tmp_single_line_revcomp.fasta"
    					else
						echo $old_line | sed -e "s/A/X/gI;s/T/A/gI;s/X/T/gI;s/G/Y/gI;s/C/G/gI;s/Y/C/gI" | rev >> "Step4_2_tmp_single_line_revcomp.fasta"
					fi	
				done < "Step4_2_tmp_single_line.fasta"

				#convert back to multiline fasta
				
				cat "Step4_2_tmp_single_line_revcomp.fasta" | awk 'BEGIN{RS=">";FS="\n"}NR>1{seq="";for (i=2;i<=NF;i++) seq=seq""$i;a[$1]=seq;b[$1]=length(seq)}END{for (i in a) {k=sprintf("%d", (b[i]/80)+1); printf ">%s\n",$1;for (j=1;j<=int(k);j++) printf "%s\n", substr(a[i],1+(j-1)*80,80)}}' >> "Step4_2_non_annotated_sequences_in_"$member"_tmp.fasta"
	
			rm -f "Step4_2_tmp_single_line.fasta" "Step4_2_tmp_single_line_revcomp.fasta"			

			else

			#extract sequence		
	
			$blastbin_path/blastdbcmd -db $member"_genomes" -dbtype nucl -entry $contig -range $start-$stop -outfmt "%f"  >> "Step4_2_non_annotated_sequences_in_"$member"_tmp.fasta"
			
			fi		
		done < "Step3_6_non_annotated_in_"$member".identifier"

		#add correct identifier to sequence
	
		#create array with new IDs
	
		IFS=$'\n' read -d '' -r -a new_ID < "Step4_1_non_annotated_sequences_in_"$member".annotation"
		n=0
	
		#replace old IDs with new IDs
	
		while read old_line
			do
    				if [[ "$old_line" == ">"* ]]
					then
       					echo ${new_ID[n]} >> "Step4_2_non_annotated_sequences_in_"$member".fasta"
       					((n=n+1))
    				else
					echo $old_line >> "Step4_2_non_annotated_sequences_in_"$member".fasta"	
				fi
	
		done < "Step4_2_non_annotated_sequences_in_"$member"_tmp.fasta"	
	
		cat $orfs_path/$type/$member".fasta" "Step4_2_non_annotated_sequences_in_"$member".fasta" > Xtra/orfs/$type/$member".fasta"
			
	
		#clean up temporary files

		rm -f "Step3_6_non_annotated_in_"$member"_tmp"*".identifier" "Step4_2_non_annotated_sequences_in_"$member"_tmp.fasta" 
	
	done <  $type"_members.txt"
	else
	
	cp -R -f $orfs_path/$type ./Xtra/orfs
	
	fi
done

#clean_up and copy files to corresponding directories

for (( x=1; x<=4 ; x++ ))
	do
	if (( $x < 4 ))
		then
		mkdir ./Step_$x
		mv ./Step$x*.* ./Step_$x

	elif (( $x == 4 )) 
		then
		mkdir ./Step_$x
		mv ./Step$x*.* ./Step_$x
	fi
done

cp -R -f genomes ./Xtra
mkdir dbs raw 
mv -f genomes orfs ./raw
mv *.n* *.log *.txt *.fasta *.identifier ./dbs/


#end of function -time

etime=$(date +"%s")

#calculate the elapsed time and print it to settings-files

elapsed_time=$(($etime-$stime))

echo "Elapsed processor time:" $(($elapsed_time / 60))"min and" $(($elapsed_time % 60))"sec"
echo	

