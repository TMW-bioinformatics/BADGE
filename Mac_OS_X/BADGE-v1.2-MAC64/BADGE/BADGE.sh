#!/bin/bash

#BADGE (BlAst based Diagnostic Gene findEr)
#Version 1.2
#Copyright (C) 2016 Juergen Behr & Andreas Geissler

#GPL3
#This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version. This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details. You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
#No warranty is given for correct function of the sowftware. You should assure yourself, that the software function is correct according to your own criteria.

#Binaries used by BADGE, found within the BADGE/bin directory are third party binaries and are distributed under GPL (fastatranslate, exonerate, EBI) and Public Domain (BLAST+ toolkit, NCBI). Licenses are included within the BADGE/bin directory

#Contact information: juergen.behr@wzw.tum.de

#Quick start: 1.Extract BADGE to your home directory (or any other desired directory)
#             2.Check the "installation" from terminal by executing the check_BADGE.sh script within the BADGE/t-data directory (terminal / command line)
#             3.Create directories BADGE/genomes & BADGE/orfs
#             4.Create directories corresponding to your groups within BADGE/genomes & BADGE/orfs (e.g. BADGE/genomes/A & BADGE/orfs/A as well as BADGE/genomes/B & BADGE/orfs/B)
#             5.Place files with genomes and orfs (identically named) into corresponding directories
#             6.Start BADGE by using the BADGE.sh script (move to BADGE directory within terminal or place BADGE-directory in your $PATH variable)
#	      7.If BADGE can not be started - also check your bash path (terminal: "which bash"; default: /bin/bash ) - if necassary change it (first line of this script)
#For detailed description of installation and running BADGE - see the MANUAL

##################################################################################################################################################################################################

#Description of settings:

#Clean_up can be set to false / true (default). If set to true, only the most important output files will be kept.
#Minimum DMG occurrence can be set until 1, while 1 means that DMGs have to be present in 100% of the genomes of a given type.
#BLAST settings - parameter definition: perc_identity_cut = threshold value of percent identity, e_value = e-value, group_qscov = alignment lenght divided by query or subject lenght
	#MEGABLAST seetings include parameters to adjust sensitivity. DC-mode: DC-MEGABLAST is used instead of MEGABLAST for the basic prediction of DMGs - slower but more sensitive, also detects shared DMGs within the target group having variants with deletions / gaps, NOTE: settings applied to basic identifcation (also in DC-mode!) are the ones within the MEGABLAST settings section, the DC-MEGABLAST filter settings are only applied to the DC-MEGABLAST filter!
	#DC-MEGABLAST filter settings include a switch to turn the filter off (dc_filter=false) as well as parameters to adjust sensitivity.
	#BLASTN filter settings include a switch to turn the filter off (blastn_filter=false) as well as parameters to adjust sensitivity.
	#PROTEIN-LEVEL mode: can be set to true - as a consequence DMGs are searched for on protein level using amino acid sequences - DC-MEGABLAST filter & BLASTN filter will be set to false in case you use that mode
	#MUT-LEVEL mode: can be set to true - as a consequence all DMGs are searched, which are exactly identical within one group and have ANY difference in the other group - DC-MEGABLAST filter & BLASTN filter will be set to false in case you use that mode
 	#Identify overlapping DMGs can be set to true / false (default). If set to true overlapping DMGs are labeled correspondingly. 

##################################################################################################################################################################################################
#TODO: Settings - adjust your settings and modify filters if desired TODO
       #############################################################

#Clean up - default true
clean_up=true

#Minimum DMG occurrence - default 1
min_DMG_occurrence=1

#Check header for special character and replace by "_" - default true
special_character=true

#BLAST settings:

#Number of parallel blast processes - default 4:
num_blast_proc=4

#MEGABLAST settings - default 95 / 0.000000000000001 / 0.95 / 0.50 / false
megablast_perc_identity_cut=95
megablast_e_value=0.000000000000001
megablast_within_group_qscov=0.95
megablast_between_group_qscov=0.50
dc_mode=false

#DC-MEGABLAST filter settings - default true / 70 / 10 / 0.50
dc_filter=true
dc_perc_identity_cut=70
dc_blast_e_value=10
dc_between_group_qscov=0.50

#BLASTN filter settings - default true / 95 / 10 / 0.25
blastn_filter=true
blastn_perc_identity_cut=95
blastn_e_value=10
blastn_between_group_qscov=0.25

#Search for DMGs via protein blastp - PROTEIN-LEVEL BADGE

#PROTEIN-LEVEL options - default false / 50 / 10 / 0.50 / 0.50 / 11 / 1 / true:
protein_level=false
blastp_perc_identity_cut=50
blastp_e_value=10
blastp_within_group_qscov=0.50
blastp_between_group_qscov=0.50
fastatranslate_geneticcode=11
fastatranslate_frame=1
#clean up translated orfs - true means clean up files after BADGE is done
protein_level_clean_up=true

#Identify overlapping DMGs - default false
identify_overlapping=false

#Search for DMGs with ANY differences - MUT-LEVEL mode

#MUT-LEVEL otions - default false / false
mut_level_nt=false
mut_level_aa=false

##################################################################################################################################################################################################

#check if dc-mode is activated, if not megablast is used to predict DMGs

if $dc_mode
	then
	mb_task=dc-megablast
	mb_display=DC-MEGABLAST
else
	mb_task=megablast
	mb_display=MEGABLAST
fi

#settings-check - only 1 MUT-LEVEL mode is allowed to be acitvated

if $mut_level_nt && $mut_level_aa
	then
	echo
	echo "Warning - you have swiched on mut_level_nt and mut_level_aa - you have to turn off either of them"
	echo
	exit 1
fi

#settings-check - if PROTEIN-LEVEL, MUT-LEVEL is active, DC-MEGABLAST filter and BLASTN filter are disabled automatically

if $protein_level || $mut_level_nt || $mut_level_aa
	then	
	dc_filter=false
	blastn_filter=false
	echo
	echo "Warning - if PROTEIN-LEVEL or MUT-LEVEL is active DC-MEGABLAST filter and BLASTN filter are disabled automatically"
	echo
fi

#settings-change - MUT-LEVEL parameters from the settings section are overwritten

if $mut_level_nt
	then
	protein_level=false
	megablast_perc_identity_cut=100
	megablast_e_value=0.000000000000001
	megablast_within_group_qscov=1
	megablast_between_group_qscov=1
	echo
	echo "MUT-LEVEL mode - BADGE will predict all DMGs which are exactly identical within one group and have ANY differences to corresponding sequences in the other group"
	echo
fi

if $mut_level_aa
	then
	protein_level=true
	blastp_perc_identity_cut=100
	blastp_e_value=10
	blastp_within_group_qscov=1
	blastp_between_group_qscov=1
	#also the genome filter has to be set to maximum
	megablast_perc_identity_cut=100
	megablast_e_value=0.000000000000001
	megablast_within_group_qscov=1
	megablast_between_group_qscov=1
	echo
	echo "MUT-LEVEL mode - BADGE will predict all DMGs which are exactly identical within one group and have ANY differences to corresponding sequences in the other group"
	echo
fi

#store initially chosen number of blast processes

set_num_blast_proc=$num_blast_proc

##################################################################################################################################################################################################
#changes for mac based versions

platform=`uname`
if [[ $platform == 'Darwin' ]]
then
#use higher version of grep, awk, sed
shopt -s expand_aliases
alias grep="../bin/grep"
alias awk="../bin/gawk"
alias sed="../bin/sed"
#locale setting
LANG="POSIX"
export LANG
LC_COLLATE="POSIX"
export LC_COLLATE
LC_CTYPE="POSIX"
export LC_CTYPE
LC_MESSAGES="POSIX"
export LC_MESSAGES
LC_MONETARY="POSIX"
export LC_MONETARY
LC_NUMERIC="POSIX"
export LC_NUMERIC
LC_TIME="POSIX"
export LC_TIME
fi
##################################################################################################################################################################################################

#helper functions

get_fasta () {

#USAGE: get_fasta input.identifier blastdb output.fasta

$blastbin_path/blastdbcmd -db $2 -entry_batch $1 >> $3

}

get_frequency_distribution () {

#USAGE: get_frequency_distribution input_sort.identifier input_blast.identifier output.frequency or output.distribution; switch (or): true = frequency, false = distribution

while read IDs
	do
	x=1
	first_ID=`echo $IDs | awk '{print $1}'`

	for blasts in $type1_dbname_list
		do
		y=0
		for ID in $IDs
			do 	
			if grep -Fxq $ID $2$blasts"_blast.identifier"
				then
				if $4
   			 		then
					y=$(( y+1 ))
				else
 					# code if found
					y=1
				fi
			fi
			
		done
		
		if (($x == 1))
			then
    			ID_check="$first_ID\t$y"
		else
			ID_check="$ID_check\t$y"
		fi
		x=$(( x+1 ))
	done
	echo -e $ID_check >> $3	
done < $1
}

translate () {

#USAGE: translate input.fasta output.fasta geneticcode

cat $1 | sed "s/>//2g"| awk 'BEGIN{RS=">";FS="\n"}NR>1{seq="";for (i=2;i<=NF;i++) seq=seq""$i; print ">"$1"\n"seq}' > single_line.fasta

grep "^>" single_line.fasta > identifier.txt
grep -v "^>" single_line.fasta > sequence.txt

cat sequence.txt | awk '{print tolower($0)}'| awk -v geneticcode=$3 'BEGIN{

if (geneticcode == 11 || geneticcode == 1) {
c["atg"]="M"; c["ttt"]="F"; c["ttc"]="F"; c["tta"]="L"; c["ttg"]="L"; c["ctt"]="L"; c["ctc"]="L"; c["cta"]="L"; c["ctg"]="L"
c["att"]="I"; c["atc"]="I"; c["ata"]="I"; c["gtt"]="V"; c["gtc"]="V"; c["gta"]="V"; c["gtg"]="V"; c["tct"]="S"; c["tcc"]="S"; c["tca"]="S"; c["tcg"]="S"; c["cct"]="P"; c["ccc"]="P"; c["cca"]="P";c["ccg"]="P"
c["act"]="T"; c["acc"]="T"; c["aca"]="T"; c["acg"]="T"; c["gct"]="A";c["gcc"]="A"; c["gca"]="A"; c["gcg"]="A"; c["tat"]="Y"; c["tac"]="Y"; c["cat"]="H"; c["cac"]="H"; c["caa"]="Q"; c["cag"]="Q"; c["aat"]="N"; c["aac"]="N"
c["aaa"]="K"; c["aag"]="K"; c["gat"]="D"; c["gac"]="D"; c["gaa"]="E"; c["gag"]="E"; c["tgt"]="C"; c["tgc"]="C"; c["tgg"]="W"; c["cgt"]="R"; c["cgc"]="R"; c["cga"]="R"; c["cgg"]="R"; c["aga"]="R"; c["agg"]="R"
c["agt"]="S";  c["agc"]="S"; c["ggt"]="G"; c["ggc"]="G"; c["gga"]="G"; c["ggg"]="G"; c["taa"]="*"; c["tag"]="*"; c["tga"]="*"}

else if (geneticcode == 4) {
c["atg"]="M"; c["ttt"]="F"; c["ttc"]="F"; c["tta"]="L"; c["ttg"]="L"; c["ctt"]="L"; c["ctc"]="L"; c["cta"]="L"; c["ctg"]="L"
c["att"]="I"; c["atc"]="I"; c["ata"]="I"; c["gtt"]="V"; c["gtc"]="V"; c["gta"]="V"; c["gtg"]="V"; c["tct"]="S"; c["tcc"]="S"; c["tca"]="S"; c["tcg"]="S"; c["cct"]="P"; c["ccc"]="P"; c["cca"]="P";c["ccg"]="P"
c["act"]="T"; c["acc"]="T"; c["aca"]="T"; c["acg"]="T"; c["gct"]="A";c["gcc"]="A"; c["gca"]="A"; c["gcg"]="A"; c["tat"]="Y"; c["tac"]="Y"; c["cat"]="H"; c["cac"]="H"; c["caa"]="Q"; c["cag"]="Q"; c["aat"]="N"; c["aac"]="N"
c["aaa"]="K"; c["aag"]="K"; c["gat"]="D"; c["gac"]="D"; c["gaa"]="E"; c["gag"]="E"; c["tgt"]="C"; c["tgc"]="C"; c["tgg"]="W"; c["tga"]="W"; c["cgt"]="R"; c["cgc"]="R"; c["cga"]="R"; c["cgg"]="R"; c["aga"]="R"; c["agg"]="R"
c["agt"]="S";  c["agc"]="S"; c["ggt"]="G"; c["ggc"]="G"; c["gga"]="G"; c["ggg"]="G"; c["taa"]="*"; c["tag"]="*"}

else {
c["atg"]="M"; c["ttt"]="F"; c["ttc"]="F"; c["tta"]="L"; c["ttg"]="L"; c["ctt"]="L"; c["ctc"]="L"; c["cta"]="L"; c["ctg"]="L"
c["att"]="I"; c["atc"]="I"; c["ata"]="I"; c["gtt"]="V"; c["gtc"]="V"; c["gta"]="V"; c["gtg"]="V"; c["tct"]="S"; c["tcc"]="S"; c["tca"]="S"; c["tcg"]="S"; c["cct"]="P"; c["ccc"]="P"; c["cca"]="P";c["ccg"]="P"
c["act"]="T"; c["acc"]="T"; c["aca"]="T"; c["acg"]="T"; c["gct"]="A";c["gcc"]="A"; c["gca"]="A"; c["gcg"]="A"; c["tat"]="Y"; c["tac"]="Y"; c["cat"]="H"; c["cac"]="H"; c["caa"]="Q"; c["cag"]="Q"; c["aat"]="N"; c["aac"]="N"
c["aaa"]="K"; c["aag"]="K"; c["gat"]="D"; c["gac"]="D"; c["gaa"]="E"; c["gag"]="E"; c["tgt"]="C"; c["tgc"]="C"; c["tgg"]="W"; c["cgt"]="R"; c["cgc"]="R"; c["cga"]="R"; c["cgg"]="R"; c["aga"]="R"; c["agg"]="R"
c["agt"]="S";  c["agc"]="S"; c["ggt"]="G"; c["ggc"]="G"; c["gga"]="G"; c["ggg"]="G"; c["taa"]="*"; c["tag"]="*"; c["tga"]="*"}

}
{i=1; p=""}
{do {
s=substr($0, i, 3)
{if (c[s]=="") {p=p"*"} else {p=p c[s]""}}
i=i+3}
while (s!="")}
{printf("%s\n", p)}' >> sequence_aa.txt

paste -d '\n' identifier.txt sequence_aa.txt | awk '{gsub("[*]+", ""); print}' > $2

rm -f single_line.fasta sequence.txt sequence_aa.txt identifier.txt

}

##################################################################################################################################################################################################

#get BADGE directory

BADGE_path=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
cd $BADGE_path

##################################################################################################################################################################################################

#start of blast-pipe-function

BADGE_function() {

numsteps=6

#create necassary directoriy named like comparison which is done

type1=$1
type2=$2
comp_tag=$type1"_vs_"$type2
if [[ -d "$comp_tag" ]]
	then
	echo
	echo "Warning - $comp_tag already exists - delete or move the whole directory!"
	echo
	exit 1		
fi

mkdir $comp_tag
cd $comp_tag
exec 2> >(tee -a error.log >&2)

#create settings file

echo "Current settings for BADGE run:" > .BADGE.settings
echo >> .BADGE.settings
echo	"#clean up - default true" >> .BADGE.settings
echo	"clean_up=$clean_up" >> .BADGE.settings
echo >> .BADGE.settings	
echo	"#Minimum DMG occurrence - default 1" >> .BADGE.settings
echo	"min_DMG_occurrence=$min_DMG_occurrence" >> .BADGE.settings
echo >> .BADGE.settings
echo	"#Check header for special character and replace by _ - default true" >> .BADGE.settings
echo	"special_character=$special_character" >> .BADGE.settings
echo >> .BADGE.settings
echo	"#BLAST settings:" >> .BADGE.settings
echo >> .BADGE.settings
echo 		"#Number of parallel blast processes - default 4" >> .BADGE.settings
echo		"num_blast_proc="$num_blast_proc >> .BADGE.settings
echo >> .BADGE.settings	
echo		"#MEGABLAST settings - default 95 / 0.000000000000001 / 0.95 / 0.50 / false"  >> .BADGE.settings
echo		"megablast_perc_identity_cut=$megablast_perc_identity_cut" >> .BADGE.settings
echo		"megablast_e_value=$megablast_e_value" >> .BADGE.settings
echo		"megablast_within_group_qscov=$megablast_within_group_qscov" >> .BADGE.settings
echo		"megablast_between_group_qscov=$megablast_between_group_qscov" >> .BADGE.settings
echo		"dc_mode=$dc_mode" >> .BADGE.settings
echo >> .BADGE.settings	
echo		"#DC-MEGABLAST filter settings - default true / 70 / 10 / 0.50)" >> .BADGE.settings
echo		"dc_filter=$dc_filter" >> .BADGE.settings
echo		"dc_perc_identity_cut=$dc_perc_identity_cut" >> .BADGE.settings
echo		"dc_blast_e_value=$dc_blast_e_value" >> .BADGE.settings
echo		"dc_between_group_qscov=$dc_between_group_qscov" >> .BADGE.settings
echo >> .BADGE.settings
echo		"#BLASTN filter settings - defaul true / 95 / 10 / 0.25" >> .BADGE.settings
echo		"blastn_filter=$blastn_filter" >> .BADGE.settings
echo		"blastn_perc_identity_cut=$blastn_perc_identity_cut" >> .BADGE.settings
echo		"blastn_e_value=$blastn_e_value" >> .BADGE.settings
echo		"blastn_between_group_qscov=$blastn_between_group_qscov" >> .BADGE.settings
echo >> .BADGE.settings
echo		"#Search for potential markers via protein blastp - PROTEIN-LEVEL BADGE" >> .BADGE.settings
echo		"#PROTEIN-LEVEL options - default false / 50 / 10 / 0.50 / 0.50 / true"  >> .BADGE.settings
echo		"protein_level=$protein_level"  >> .BADGE.settings
echo		"blastp_perc_identity_cut=$blastp_perc_identity_cut"  >> .BADGE.settings
echo		"blastp_e_value=$blastp_e_value"  >> .BADGE.settings
echo		"blastp_within_group_qscov=$blastp_within_group_qscov"  >> .BADGE.settings
echo		"blastp_between_group_qscov=$blastp_between_group_qscov"  >> .BADGE.settings
echo		"fastatranslate_geneticcode=$fastatranslate_geneticcode"  >> .BADGE.settings
echo		"fastatranslate_frame=$fastatranslate_frame"  >> .BADGE.settings
echo		"#clean up translated orfs - true means clean up files after BADGE is done" >> .BADGE.settings
echo		"protein_level_clean_up=$protein_level_clean_up" >> .BADGE.settings
echo >> .BADGE.settings
echo		"#Identify overlapping DMGs - default false"  >> .BADGE.settings
echo		"identify_overlapping=$identify_overlapping"  >> .BADGE.settings
echo >> .BADGE.settings
echo		"#Search for DMGs with ANY differences - MUT-LEVEL mode" >> .BADGE.settings
echo		"#MUT-LEVEL otions - default false / false" >> .BADGE.settings
echo		"mut_level_nt=$mut_level_nt" >> .BADGE.settings
echo		"mut_level_aa=$mut_level_aa" >> .BADGE.settings
if $protein_level || $mut_level_nt || $mut_level_aa
	then	
	echo >> .BADGE.settings
	echo "Warning - if PROTEIN-LEVEL or MUT-LEVEL is active DC-MEGABLAST filter and BLASTN filter are disabled automatically" >> .BADGE.settings
fi
if $mut_level_nt || $mut_level_aa
	then
	echo >> .BADGE.settings
	echo "MUT-LEVEL mode - BADGE will predict all DMGs which are exactly identical within one group and have any differences to corresponding sequences in the other group" >> .BADGE.settings
fi

#create databases

echo
echo
echo
echo -e "#######################################################################"

echo -e "BADGE - Search for $type1 specific DMGs"
echo -e "#######################################################################"
echo
echo
echo -e "#######################################################################"
echo -ne "Creating BLAST databases\r"


#define paths and create additional directories if PROTEIN-LEVEL is true

blastbin_path=../bin
type1_genomes_path=../genomes/$type1
type2_genomes_path=../genomes/$type2
type1_orfs_path=../orfs/$type1
type2_orfs_path=../orfs/$type2
if $protein_level
	then
	if [[ ! -d ../orfs_aa ]]
		then
		mkdir ../orfs_aa
	fi
	if [[ ! -d ../orfs_aa/$type1 ]]
		then
		mkdir ../orfs_aa/$type1
	fi
	if [[ ! -d ../orfs_aa/$type2 ]]
		then
		mkdir ../orfs_aa/$type2
	fi
type1_orfs_path_aa=../orfs_aa/$type1
type2_orfs_path_aa=../orfs_aa/$type2
fi

#clear problems with special characters in fasta-header - if a particular special character, found in your files is not replaced automatically - insert that special character in the following expression "[\\|'\''()=/,.:]+" - consider gsub special character rules

if $special_character
	then

	for i in $type1_orfs_path/*.fasta
		do
		dbname=$(basename "$i" .fasta)
		cat $i | awk '{gsub("[\\|'\''()=/,.:]+", "_"); print}' > $type1_orfs_path/$dbname".tmp"
		mv -f $type1_orfs_path/$dbname".tmp" $type1_orfs_path/$dbname".fasta"
	done

	for i in $type2_orfs_path/*.fasta
		do
		dbname=$(basename "$i" .fasta)
		cat $i | awk '{gsub("[\\|'\''()=/,.:]+", "_"); print}' > $type2_orfs_path/$dbname".tmp"
		mv -f $type2_orfs_path/$dbname".tmp" $type2_orfs_path/$dbname".fasta"
	done

	for i in $type1_genomes_path/*.fasta
		do
		dbname=$(basename "$i" .fasta)
		cat $i | awk '{gsub("[\\|'\''()=/,.:]+", "_"); print}' > $type1_genomes_path/$dbname".tmp"
		mv -f $type1_genomes_path/$dbname".tmp" $type1_genomes_path/$dbname".fasta"
	done

	for i in $type2_genomes_path/*.fasta
		do
		dbname=$(basename "$i" .fasta)
		cat $i | awk '{gsub("[\\|'\''()=/,.:]+", "_"); print}' > $type2_genomes_path/$dbname".tmp"
		mv -f $type2_genomes_path/$dbname".tmp" $type2_genomes_path/$dbname".fasta"
	done

fi

#make blast dbs for orf-files of all members of type 1

type1_dbname_list=""
for i in $type1_orfs_path/*.fasta
	do
	dbname=$(basename "$i" .fasta)
	type1_dbname_list="$type1_dbname_list $dbname"
	$blastbin_path/makeblastdb -in $i -input_type fasta -dbtype nucl -title $dbname -parse_seqids -out $dbname -logfile $dbname"_db.log"
	$blastbin_path/blastdbcmd -db $dbname -entry all -outfmt "%i" | cut -d "|" -f 2 > $type1"_"$dbname"_orfs.identifier"
done

#make blast dbs for genome-files of all members of type 1

type1_dbname_list_genome=""
for i in $type1_genomes_path/*.fasta
	do
	dbname=$(basename "$i" .fasta)
	type1_dbname_list_genome="$type1_dbname_list_genome $dbname"
	$blastbin_path/makeblastdb -in $i -input_type fasta -dbtype nucl -title $dbname"_genome" -parse_seqids -out $dbname"_genome" -logfile $dbname"_genome_db.log"
done

#make blast dbs for orf-files of all members of type 2

type2_dbname_list=""
for i in $type2_orfs_path/*.fasta
	do
	dbname=$(basename "$i" .fasta)
	type2_dbname_list="$type2_dbname_list $dbname"
	$blastbin_path/makeblastdb -in $i -input_type fasta -dbtype nucl -title $dbname -parse_seqids -out $dbname -logfile $dbname"_db.log"
	$blastbin_path/blastdbcmd -db $dbname -entry all -outfmt "%i" | cut -d "|" -f 2 > $type2"_"$dbname"_orfs.identifier"
done

#combine orf sequences

cat $type1_orfs_path/*.fasta > $type1"_orfs.fasta"
cat $type2_orfs_path/*.fasta > $type2"_orfs.fasta"

#combine genome sequences

cat $type1_genomes_path/*.fasta > $type1"_genomes.fasta"
cat $type2_genomes_path/*.fasta > $type2"_genomes.fasta"

#make blast dbs for combined type orfs

$blastbin_path/makeblastdb -in $type1"_orfs.fasta" -input_type fasta -dbtype nucl -title $type1"_orfs" -parse_seqids -out $type1"_orfs" -logfile $type1"_orfs_db.log"
$blastbin_path/makeblastdb -in $type2"_orfs.fasta" -input_type fasta -dbtype nucl -title $type2"_orfs" -parse_seqids -out $type2"_orfs" -logfile $type2"_orfs_db.log"

#make blast dbs for combined type genomes

$blastbin_path/makeblastdb -in $type1"_genomes.fasta" -input_type fasta -dbtype nucl -title $type1"_genomes" -parse_seqids -out $type1"_genomes" -logfile $type1"_genomes_db.log"
$blastbin_path/makeblastdb -in $type2"_genomes.fasta" -input_type fasta -dbtype nucl -title $type2"_genomes" -parse_seqids -out $type2"_genomes" -logfile $type2"_genomes_db.log"

#get orf IDs for all combined type orfs databases mac version: sort before

$blastbin_path/blastdbcmd -db $type1"_orfs" -entry all -outfmt "%i" | cut -d "|" -f 2 > $type1"_orfs.identifier"
$blastbin_path/blastdbcmd -db $type2"_orfs" -entry all -outfmt "%i" | cut -d "|" -f 2 > $type2"_orfs.identifier"

#if PROTEIN-LEVEL is true - corresponding files and databases are made

if $protein_level
	
	then

	#translate orf-files into proteins - frame 1, genetic code 11 for members of both types
	
	for i in $type1_orfs_path/*.fasta
		do
		dbname=$(basename "$i" .fasta)
		if [[ ! -e $type1_orfs_path_aa/$dbname".fasta" ]]
			then
			$blastbin_path/fastatranslate -f $i --geneticcode $fastatranslate_geneticcode -F $fastatranslate_frame | sed "s/translate(1)//" | awk '{gsub("[\\|\\[\\],.:]+", " "); print}' | awk '{gsub("[*]+", ""); print}' | sed '/^$/d' > $type1_orfs_path_aa/$dbname".fasta"
		fi
	done
	
	for i in $type2_orfs_path/*.fasta
		do
		dbname=$(basename "$i" .fasta)
		if [[ ! -e $type2_orfs_path_aa/$dbname".fasta" ]]
			then
			$blastbin_path/fastatranslate -f $i --geneticcode $fastatranslate_geneticcode -F $fastatranslate_frame | sed "s/translate(1)//" | awk '{gsub("[\\|\\[\\],.:]+", " "); print}' | awk '{gsub("[*]+", ""); print}' | sed '/^$/d' > $type2_orfs_path_aa/$dbname".fasta"
		fi
	done

	#make blast dbs for orf_aa-files of all members of type 1

	type1_dbname_list_aa=""
	for i in $type1_orfs_path_aa/*.fasta
		do
		dbname=$(basename "$i" .fasta)
		type1_dbname_list_aa="$type1_dbname_list_aa $dbname"
		$blastbin_path/makeblastdb -in $i -input_type fasta -dbtype prot -title $dbname -parse_seqids -out $dbname"_orfs_aa" -logfile $dbname"_orfs_db_aa.log"
		$blastbin_path/blastdbcmd -db $dbname -entry all -outfmt "%i" | cut -d "|" -f 2 > $type1"_"$dbname"_orfs_aa.identifier"
	done

	#make blast dbs for orf_aa-files of all members of type 2

	type2_dbname_list_aa=""
	for i in $type2_orfs_path_aa/*.fasta
		do
		dbname=$(basename "$i" .fasta)
		type2_dbname_list_aa="$type2_dbname_list_aa $dbname"
		$blastbin_path/makeblastdb -in $i -input_type fasta -dbtype prot -title $dbname -parse_seqids -out $dbname"_orfs_aa" -logfile $dbname"_orfs_db_aa.log"
		$blastbin_path/blastdbcmd -db $dbname -entry all -outfmt "%i" | cut -d "|" -f 2 > $type1"_"$dbname"_orfs_aa.identifier"
	done
	
	#combine orf_aa sequences

	cat $type1_orfs_path_aa/*.fasta > $type1"_orfs_aa.fasta"
	cat $type2_orfs_path_aa/*.fasta > $type2"_orfs_aa.fasta"

	#make blast dbs for combined type orfs

	$blastbin_path/makeblastdb -in $type1"_orfs_aa.fasta" -input_type fasta -dbtype prot -title $type1"_orfs_aa" -parse_seqids -out $type1"_orfs_aa" -logfile $type1"_orfs_db_aa.log"
	$blastbin_path/makeblastdb -in $type2"_orfs_aa.fasta" -input_type fasta -dbtype prot -title $type2"_orfs_aa" -parse_seqids -out $type2"_orfs_aa" -logfile $type2"_orfs_db_aa.log"

	#get orf IDs for all combined type orfs databases

	$blastbin_path/blastdbcmd -db $type1"_orfs_aa" -entry all -outfmt "%i" | cut -d "|" -f 2 > $type1"_orfs_aa.identifier"
	$blastbin_path/blastdbcmd -db $type2"_orfs_aa" -entry all -outfmt "%i" | cut -d "|" -f 2 > $type2"_orfs_aa.identifier"
	
fi

#check for correct blast-database creation

if grep -i "error" *.log
	then
	echo -e "Error - makeblastdb command failed - Check input fasta files" >&2
	break
else
	echo -e "Creating BLAST databases finished"
	echo
fi

##################################################################################################################################################################################################

#Step 1 - Get Potential DMGs

if $protein_level

	then

	echo
	echo -e "#######################################################################"
	echo -e "Step 1 of $numsteps:  BLASTP all $type2 orfs vs $type1 orfs - Get $type1 DMGs"
	echo

	#remove redundant (identical) orfs  

	cat $type2"_orfs_aa.fasta" | awk '/^>/ {printf("\n%s\n",$0);next; } { printf("%s",$0);}  END {printf("\n");}' | awk 'NF' | awk '!(NR%2){print$0"\t"p}{p=$0}' | sort -k1 | awk '!($1 in a){a[$1]; print}' | awk '{print$2"\n"$1}' > $type2"_orfs_aa_tmp.fasta"

	#blastp type1 versus type2 orfs
	
	#split fasta files for multiprocessing

	cat $type2"_orfs_aa_tmp.fasta" > split_input.fasta
	seq_num=`grep -c ">" split_input.fasta`
	if [[ $num_blast_proc -gt $seq_num ]]
		then
		num_blast_proc=1
		else
		num_blast_proc=$set_num_blast_proc
	fi
	split_at_num=$(( seq_num/num_blast_proc ))
	awk -v split_at_num=$split_at_num -v fastafilebasename="seq_split" 'BEGIN {n_seq=0;} /^>/ {if(n_seq%split_at_num==0){fastafile=sprintf(fastafilebasename"%d.fasta",n_seq);} print >> fastafile; n_seq++; next;} { print >> fastafile; }' < split_input.fasta

	#perform blast

	query_num=1
	for queryfiles in ./seq_split*".fasta"
		do
		$blastbin_path/blastp -db $type1"_orfs_aa" -query $queryfiles -outfmt "6 qseqid sseqid qlen slen pident length evalue" -max_target_seqs 100 -num_threads 4 | awk -v blastp_between_group_qscov=$blastp_between_group_qscov -v blastp_perc_identity_cut=$blastp_perc_identity_cut -v blastp_e_value=$blastp_e_value '{if ($6/$3 >= blastp_between_group_qscov && $6/$4 >= blastp_between_group_qscov && $5 >= blastp_perc_identity_cut && $7 <= blastp_e_value) print $0}' > "seq_split_"$query_num".blast" &
		query_num=$(( query_num+1 ))	
		done
	wait
	cat "seq_split_"*".blast" > "Step1_1_"$type2"_vs_"$type1"_orfs.blast"

	#clean up split files and temporary files

	rm -f "seq_split_"*".blast"  "seq_split"*".fasta" split_input.fasta $type2"_orfs_aa_tmp.fasta"

else

	echo
	echo -e "#######################################################################"
	echo -e "Step 1 of $numsteps:  $mb_display all $type2 orfs vs $type1 orfs - Get $type1 DMGs"
	echo

	#remove redundant (identical) orfs 

	cat $type2"_orfs.fasta" | awk '/^>/ {printf("\n%s\n",$0);next; } { printf("%s",$0);}  END {printf("\n");}' | awk 'NF' | awk '!(NR%2){print$0"\t"p}{p=$0}' | sort -k1 | awk '!($1 in a){a[$1]; print}' | awk '{print$2"\n"$1}' > $type2"_orfs_tmp.fasta"

	#megablast type1 versus type2 orfs

	#split fasta files for multiprocessing

	cat $type2"_orfs_tmp.fasta" > split_input.fasta
	seq_num=`grep -c ">" split_input.fasta`
	if [[ $num_blast_proc -gt $seq_num ]]
		then
		num_blast_proc=1
		else
		num_blast_proc=$set_num_blast_proc
	fi
	split_at_num=$(( seq_num/num_blast_proc ))
	awk -v split_at_num=$split_at_num -v fastafilebasename="seq_split" 'BEGIN {n_seq=0;} /^>/ {if(n_seq%split_at_num==0){fastafile=sprintf(fastafilebasename"%d.fasta",n_seq);} print >> fastafile; n_seq++; next;} { print >> fastafile; }' < split_input.fasta

	#perform blast

	query_num=1
	for queryfiles in ./seq_split*".fasta"
		do
		$blastbin_path/blastn -db $type1"_orfs" -query $queryfiles -outfmt "6 qseqid sseqid qlen slen pident length evalue" -max_target_seqs 500 -num_threads 4 -task $mb_task | awk -v megablast_between_group_qscov=$megablast_between_group_qscov -v megablast_perc_identity_cut=$megablast_perc_identity_cut -v megablast_e_value=$megablast_e_value '{if ($6/$3 >= megablast_between_group_qscov && $6/$4 >= megablast_between_group_qscov && $5 >= megablast_perc_identity_cut && $7 <= megablast_e_value) print $0}' > "seq_split_"$query_num".blast" &
		query_num=$(( query_num+1 ))	
		done
	wait
	cat "seq_split_"*".blast" > "Step1_1_"$type2"_vs_"$type1"_orfs.blast"

	#clean up split files and temporary files

	rm -f "seq_split_"*".blast"  "seq_split"*".fasta" split_input.fasta $type2"_orfs_tmp.fasta"

fi


#remove duplicate megablast matches

cat "Step1_1_"$type2"_vs_"$type1"_orfs.blast" | awk '{print $2}' | sort | uniq > "Step1_2_"$type2"_vs_"$type1"_orfs_blast.identifier"

#get DMG orf IDs of type 1

grep -F -x -v -f "Step1_2_"$type2"_vs_"$type1"_orfs_blast.identifier" $type1"_orfs.identifier" > "Step1_3_"$type1"_DMGs.identifier"

#get fasta-sequences of DMG orfs of type 1 - as orfs

get_fasta "Step1_3_"$type1"_DMGs.identifier" $type1"_orfs" "Step1_4_"$type1"_DMGs.fasta" 

#display number of DMGs after Step 1

num_DMGs_orf_filtered=$(cat "Step1_3_"$type1"_DMGs.identifier" | wc -l )
echo -e "Number of DMGs after orf filter: $num_DMGs_orf_filtered."

#check if number of blast processes has to be reduced

if [[ $num_blast_proc -gt $num_DMGs_orf_filtered ]]
	then
	num_blast_proc=1
	else
	num_blast_proc=$set_num_blast_proc
fi

###################################################################################################################################################################################################

#Step 2 - Genome Filter

if [[ -s "Step1_4_"$type1"_DMGs.fasta" ]]
	then	
		echo
		echo -e "#######################################################################"
		echo -e "Step 2 of $numsteps:  $mb_display $type1 DMGs vs $type2 genomes - Genome filter $type1 DMGs"
		echo
	else
		echo -e "Error - Step 2 of $numsteps cant be performed - No input from Step 1" >&2
		cd $BADGE_path			
		return 1
fi

#remove redundant (identical) orfs  

#cat "Step1_4_"$type1"_DMGs.fasta" | awk '/^>/ {printf("\n%s\n",$0);next; } { printf("%s",$0);}  END {printf("\n");}' | awk 'NF' | awk '!(NR%2){print$0"\t"p}{p=$0}' | sort -k1 | awk '!($1 in a){a[$1]; print}' | awk '{print$2"\n"$1}' > "Step1_4_"$type1"_DMGs_tmp.fasta"

#megablast type1_DMGs versus type2_genomes
	
#split fasta files for multiprocessing

cat "Step1_4_"$type1"_DMGs.fasta" > split_input.fasta
	seq_num=`grep -c ">" split_input.fasta`
	if [[ $num_blast_proc -gt $seq_num ]]
		then
		num_blast_proc=1
		else
		num_blast_proc=$set_num_blast_proc
	fi
split_at_num=$(( seq_num/num_blast_proc ))
awk -v split_at_num=$split_at_num -v fastafilebasename="seq_split" 'BEGIN {n_seq=0;} /^>/ {if(n_seq%split_at_num==0){fastafile=sprintf(fastafilebasename"%d.fasta",n_seq);} print >> fastafile; n_seq++; next;} { print >> fastafile; }' < split_input.fasta

#perform blast

query_num=1
for queryfiles in ./seq_split*".fasta"
	do
	$blastbin_path/blastn -db $type2"_genomes" -query $queryfiles -outfmt "6 qseqid sseqid qlen pident length evalue" -max_target_seqs 500 -num_threads 4 -task $mb_task | awk -v megablast_between_group_qscov=$megablast_between_group_qscov -v megablast_perc_identity_cut=$megablast_perc_identity_cut -v megablast_e_value=$megablast_e_value '{if ($5/$3 >= megablast_between_group_qscov && $4 >= megablast_perc_identity_cut && $6 <= megablast_e_value) print $0}' > "seq_split_"$query_num".blast" &
	query_num=$(( query_num+1 ))		
	done
wait
cat "seq_split_"*".blast" > "Step2_1_"$type1"_DMGs_vs_"$type2"_genomes.blast"

#clean up split files and temporary files

rm -f "seq_split_"*".blast"  "seq_split"*".fasta" split_input.fasta "Step1_4_"$type1"_DMGs_tmp.fasta"

#remove duplicate megablast matches

cat "Step2_1_"$type1"_DMGs_vs_"$type2"_genomes.blast" | awk '{print $1}' | sort | uniq | cut -d "|" -f 2 > "Step2_2_"$type1"_DMGs_vs_"$type2"_genomes_blast.identifier"

#get DMG orf IDs of type 1 not present in genomes of type 2

grep -Fxv -f "Step2_2_"$type1"_DMGs_vs_"$type2"_genomes_blast.identifier" "Step1_3_"$type1"_DMGs.identifier" > "Step2_3_"$type1"_DMGs.identifier"

if $protein_level
	then
	#get fasta-sequences of DMG orfs_aa of type 1 not present in genomes of type 2

	get_fasta "Step2_3_"$type1"_DMGs.identifier" $type1"_orfs_aa" "Step2_4_"$type1"_DMGs.fasta"
else
	#get fasta-sequences of DMG orfs of type 1 not present in genomes of type 2

	get_fasta "Step2_3_"$type1"_DMGs.identifier" $type1"_orfs" "Step2_4_"$type1"_DMGs.fasta"
fi

#display number of DMGs after Step 2

num_DMGs_genomes_filtered=$(cat "Step2_3_"$type1"_DMGs.identifier" | wc -l )
echo -e "Number of DMGs after genome filter: $num_DMGs_genomes_filtered."

#check if number of blast processes has to be reduced

if [[ $num_blast_proc -gt $num_DMGs_genomes_filtered ]]
	then
	num_blast_proc=1
	else
	num_blast_proc=$set_num_blast_proc
fi

###################################################################################################################################################################################################


#Step 3 - Occurrence Filter

if [[ ! -s "Step2_4_"$type1"_DMGs.fasta" ]]
	then
		echo -e "Error - Step 3 of $numsteps cant be performed - No input from Step 2" >&2
		cd $BADGE_path			
		return 1
	elif $protein_level
		then

		echo
		echo -e "#######################################################################"
		echo -e "Step 3 of $numsteps:  BLASTP $type1 DMGs orfs vs all single $type1 orfs - Occurrence filter $type1 DMGs"
		echo
	
		#blastp genome filtered type1_DMGs vs single type 1 orfs_aa for each member of type 1

		for blast_db in $type1_dbname_list_aa
			do
			
			#split fasta files for multiprocessing

			cat "Step2_4_"$type1"_DMGs.fasta" > split_input.fasta
			seq_num=`grep -c ">" split_input.fasta`
	if [[ $num_blast_proc -gt $seq_num ]]
		then
		num_blast_proc=1
		else
		num_blast_proc=$set_num_blast_proc
	fi
			split_at_num=$(( seq_num/num_blast_proc ))
			awk -v split_at_num=$split_at_num -v fastafilebasename="seq_split" 'BEGIN {n_seq=0;} /^>/ {if(n_seq%split_at_num==0){fastafile=sprintf(fastafilebasename"%d.fasta",n_seq);} print >> fastafile; n_seq++; next;} { print >> fastafile; }' < split_input.fasta

			#perform blast

			query_num=1
			for queryfiles in ./seq_split*".fasta"
				do
				$blastbin_path/blastp -db $blast_db"_orfs_aa" -query $queryfiles -outfmt "6 qseqid sseqid qlen slen pident length evalue" -max_target_seqs 100 -num_threads 4 | awk -v blastp_within_group_qscov=$blastp_within_group_qscov -v blastp_perc_identity_cut=$blastp_perc_identity_cut -v blastp_e_value=$blastp_e_value '{if ($6/$3 >= blastp_within_group_qscov && $6/$4 >= blastp_within_group_qscov && $5 >= blastp_perc_identity_cut && $7 <= blastp_e_value) print $0}' > "seq_split_"$query_num".blast" &
				query_num=$(( query_num+1 ))	
			done
			wait
			cat "seq_split_"*".blast" > "Step3_1_"$type1"_DMGs_vs_"$blast_db".blast"

			#clean up split files

			rm -f "seq_split_"*".blast"  "seq_split"*".fasta" split_input.fasta
		
			#extract IDs		

			cat "Step3_1_"$type1"_DMGs_vs_"$blast_db".blast" | awk '{print $1}' | sort | uniq | cut -d "|" -f 2 > "Step3_2_"$type1"_DMGs_vs_"$blast_db"_blast.identifier"

		done

	else
		echo
		echo -e "#######################################################################"
		echo -e "Step 3 of $numsteps:  $mb_display $type1 DMGs orfs vs all single $type1 orfs - Occurrence filter $type1 DMGs"
		echo
	
		#megablast genome filtered type1_DMGs vs single type 1 orfs for each member of type 1

		for blast_db in $type1_dbname_list
			do
			
			#split fasta files for multiprocessing

			cat "Step2_4_"$type1"_DMGs.fasta" > split_input.fasta
			seq_num=`grep -c ">" split_input.fasta`
	if [[ $num_blast_proc -gt $seq_num ]]
		then
		num_blast_proc=1
		else
		num_blast_proc=$set_num_blast_proc
	fi
			split_at_num=$(( seq_num/num_blast_proc ))
			awk -v split_at_num=$split_at_num -v fastafilebasename="seq_split" 'BEGIN {n_seq=0;} /^>/ {if(n_seq%split_at_num==0){fastafile=sprintf(fastafilebasename"%d.fasta",n_seq);} print >> fastafile; n_seq++; next;} { print >> fastafile; }' < split_input.fasta

			#perform blast

			query_num=1
			for queryfiles in ./seq_split*".fasta"
				do
				$blastbin_path/blastn -db $blast_db -query $queryfiles -outfmt "6 qseqid sseqid qlen slen pident length evalue" -max_target_seqs 500 -num_threads 4 -task $mb_task | awk -v megablast_within_group_qscov=$megablast_within_group_qscov -v megablast_perc_identity_cut=$megablast_perc_identity_cut -v megablast_e_value=$megablast_e_value '{if ($6/$3 >= megablast_within_group_qscov && $6/$4 >= megablast_within_group_qscov && $5 >= megablast_perc_identity_cut && $7 <= megablast_e_value) print $0}' > "seq_split_"$query_num".blast" &
				query_num=$(( query_num+1 ))	
			done
			wait
			cat "seq_split_"*".blast" > "Step3_1_"$type1"_DMGs_vs_"$blast_db".blast"

			#clean up split files

			rm -f "seq_split_"*".blast"  "seq_split"*".fasta" split_input.fasta
		
			#extract IDs		

			cat "Step3_1_"$type1"_DMGs_vs_"$blast_db".blast" | awk '{print $1}' | sort | uniq | cut -d "|" -f 2 > "Step3_2_"$type1"_DMGs_vs_"$blast_db"_blast.identifier"

		done
fi

#get distribution of unique orfs of type 1 in type 1 members not present in genomes of type 2

headerstring="Orf_ID"
num_db=1
for blast_db in $type1_dbname_list
	do
	headerstring="$headerstring\t$blast_db"
done
echo -e $headerstring > "Step3_3_"$type1"_DMGs.distribution"

get_frequency_distribution "Step2_3_"$type1"_DMGs.identifier" "Step3_2_"$type1"_DMGs_vs_" "Step3_3_"$type1"_DMGs.distribution" false

#filter IDs according to min_DMG_occurrence

set_min_DMG_occurrence=$min_DMG_occurrence

while [ ! -s "Step3_4_"$type1"_DMGs_tmp.identifier" ]
	do
	cat "Step3_3_"$type1"_DMGs.distribution" | grep -Fv "Orf_ID" | awk -v min_DMG_occurrence=$min_DMG_occurrence '{
	occurrence=$2;
	for(i=3; i<=NF; i++) {
	occurrence=occurrence+$i
		};
	perc_occurrence=occurrence/(NF-1);
	if (perc_occurrence >= min_DMG_occurrence) {
	print $1;
		};
	}' | sort | uniq > "Step3_4_"$type1"_DMGs_tmp.identifier"


#check if DMGs remain after min_DMG_occurrence filter - if not proceed prompt user for new minimum DMG occurrence or continue with next type-combination

	if [[ ! -s "Step3_4_"$type1"_DMGs_tmp.identifier" ]]
		then
			echo -e "Step 4 of $numsteps cant be performed - No input from Step 3" >&2
			echo
			echo "Do you wish to decrease the minimum DMG occurrence? - [1 or 2 ENTER]:"
			select yn in "Yes" "No"; do
    				case $yn in
        				Yes ) echo; echo -n "Enter new minimum DMG occurrence [ENTER]: "; echo; read min_DMG_occurrence; break;;
        				No ) cd $BADGE_path;return 1;;
    				esac
			done
	fi
done

if $protein_level
	then
	#get fasta-sequences of DMG orfs_aa of type 1 filtered according to min_DMG_occurrence

	get_fasta "Step3_4_"$type1"_DMGs_tmp.identifier" $type1"_orfs_aa" "Step3_5_"$type1"_DMGs_tmp.fasta"

	#blastp type1 DMGs filtered according to min_DMG_occurrence versus type1 orfs

	#split fasta files for multiprocessing

	cat "Step3_5_"$type1"_DMGs_tmp.fasta" > split_input.fasta
	seq_num=`grep -c ">" split_input.fasta`
	if [[ $num_blast_proc -gt $seq_num ]]
		then
		num_blast_proc=1
		else
		num_blast_proc=$set_num_blast_proc
	fi
	split_at_num=$(( seq_num/num_blast_proc ))
	awk -v split_at_num=$split_at_num -v fastafilebasename="seq_split" 'BEGIN {n_seq=0;} /^>/ {if(n_seq%split_at_num==0){fastafile=sprintf(fastafilebasename"%d.fasta",n_seq);} print >> fastafile; n_seq++; next;} { print >> fastafile; }' < split_input.fasta

	#perform blast

	query_num=1
	for queryfiles in ./seq_split*".fasta"
		do
		$blastbin_path/blastp -db $type1"_orfs_aa" -query $queryfiles -outfmt "6 qseqid sseqid qlen slen pident length evalue" -max_target_seqs 500 -num_threads 4 |  awk -v blastp_within_group_qscov=$blastp_within_group_qscov -v blastp_perc_identity_cut=$blastp_perc_identity_cut -v blastp_e_value=$blastp_e_value '{if ($6/$3 >= blastp_within_group_qscov && $6/$4 >= blastp_within_group_qscov && $5 >= blastp_perc_identity_cut && $7 <= blastp_e_value) print $0}' > "seq_split_"$query_num".blast" &
		query_num=$(( query_num+1 ))	
	done
	wait
	cat "seq_split_"*".blast" > "Step3_6_"$type1"_DMGs_vs_"$type1"_orfs.blast"

	#clean up split files

	rm -f "seq_split_"*".blast"  "seq_split"*".fasta" split_input.fasta

else
	#get fasta-sequences of DMG orfs of type 1 filtered according to min_DMG_occurrence

	get_fasta "Step3_4_"$type1"_DMGs_tmp.identifier" $type1"_orfs" "Step3_5_"$type1"_DMGs_tmp.fasta"

	#megablast type1 DMGs filtered according to min_DMG_occurrence versus type1 orfs

	#split fasta files for multiprocessing

	cat "Step3_5_"$type1"_DMGs_tmp.fasta" > split_input.fasta
	seq_num=`grep -c ">" split_input.fasta`
	if [[ $num_blast_proc -gt $seq_num ]]
		then
		num_blast_proc=1
		else
		num_blast_proc=$set_num_blast_proc
	fi
	split_at_num=$(( seq_num/num_blast_proc ))
	awk -v split_at_num=$split_at_num -v fastafilebasename="seq_split" 'BEGIN {n_seq=0;} /^>/ {if(n_seq%split_at_num==0){fastafile=sprintf(fastafilebasename"%d.fasta",n_seq);} print >> fastafile; n_seq++; next;} { print >> fastafile; }' < split_input.fasta

	#perform blast

	query_num=1
	for queryfiles in ./seq_split*".fasta"
		do
		$blastbin_path/blastn -db $type1"_orfs" -query $queryfiles -outfmt "6 qseqid sseqid qlen slen pident length evalue" -max_target_seqs 500 -num_threads 4 -task $mb_task |  awk -v megablast_within_group_qscov=$megablast_within_group_qscov -v megablast_perc_identity_cut=$megablast_perc_identity_cut -v megablast_e_value=$megablast_e_value '{if ($6/$3 >= megablast_within_group_qscov && $6/$4 >= megablast_within_group_qscov && $5 >= megablast_perc_identity_cut && $7 <= megablast_e_value) print $0}' > "seq_split_"$query_num".blast" &
		query_num=$(( query_num+1 ))	
	done
	wait
	cat "seq_split_"*".blast" > "Step3_6_"$type1"_DMGs_vs_"$type1"_orfs.blast"

	#clean up split files

	rm -f "seq_split_"*".blast"  "seq_split"*".fasta" split_input.fasta

fi

#remove blast lcl tag

cat "Step3_6_"$type1"_DMGs_vs_"$type1"_orfs.blast" | cut -d "|" -f 2 > "Step3_6_"$type1"_DMGs_vs_"$type1"_orfs_tmp.blast"
mv -f "Step3_6_"$type1"_DMGs_vs_"$type1"_orfs_tmp.blast" "Step3_6_"$type1"_DMGs_vs_"$type1"_orfs.blast"

#put all sequence IDs matching the same DMG sequence in one line (not ordered yet) 

cat "Step3_6_"$type1"_DMGs_vs_"$type1"_orfs.blast" | awk '{
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
END{print prev " " outstring;}' > "Step3_7_"$type1"_DMGs_vs_"$type1"_orfs.identifier"

#sort sequence IDs in all lines

while read line
	do
  	#echo $ID
	echo $line | xargs -n1 | sort -u | xargs >> "Step3_8_"$type1"_DMGs_vs_"$type1"_orfs_tmp.identifier"
done < "Step3_7_"$type1"_DMGs_vs_"$type1"_orfs.identifier"

#sort DMG IDs and remove duplicates - create files with all IDs of a particular DMG per line (ordered)

sort "Step3_8_"$type1"_DMGs_vs_"$type1"_orfs_tmp.identifier" | uniq -c >> "Step3_8_"$type1"_DMGs_vs_"$type1"_orfs_tmp_sort_wc.identifier"

num_single_db=`echo $type1_dbname_list | wc -w`

abs_DMG_occurrence=`awk -v min_DMG_occurrence="$min_DMG_occurrence" -v num_single_db="$num_single_db" 'BEGIN { print min_DMG_occurrence * num_single_db}'`

touch "Step3_8_"$type1"_DMGs_vs_"$type1"_orfs_sort_no_blocks.identifier"

while read new_line
	do
	DMG_valid=true
	words_in_line=`echo $new_line | wc -w`
	DMGs_in_line=`echo $new_line | awk '{print $1;}'`
	count=$((words_in_line-DMGs_in_line))
	if [[ $count -eq 1 ]]
		then
		echo $new_line | cut -d " " -f2- >> "Step3_8_"$type1"_DMGs_vs_"$type1"_orfs_sort_blocks.identifier"
	else 
		echo $new_line | sed s/\ /\|/g | grep -iwE -f - "Step3_7_"$type1"_DMGs_vs_"$type1"_orfs.identifier" | xargs -n1 | sort | uniq -c > ID_count.txt
		while read IDs
			do
			ID_count=`echo $IDs | awk '{ print $1 }'`
			ID_count_valid=`awk -v ID_count=$ID_count -v abs_DMG_occurrence=$abs_DMG_occurrence 'BEGIN { if (ID_count >= abs_DMG_occurrence) {print "true";} else { print "false" } }'`

			if ! ( $ID_count_valid && $DMG_valid )
				then
					DMG_valid=false
					break;			
			fi
	
		done < ID_count.txt
		if $DMG_valid
			then
			echo $new_line | cut -d " " -f2- >> "Step3_8_"$type1"_DMGs_vs_"$type1"_orfs_sort_no_blocks.identifier"
		fi 
	
	fi 
done < "Step3_8_"$type1"_DMGs_vs_"$type1"_orfs_tmp_sort_wc.identifier"

cat "Step3_8_"$type1"_DMGs_vs_"$type1"_orfs_sort_blocks.identifier" "Step3_8_"$type1"_DMGs_vs_"$type1"_orfs_sort_no_blocks.identifier" | awk '{ print NF, $0 }' | sort -k2,2 -k1nr | cut -d" " -f2-| awk '$1!=p{print;p=$1}' >> "Step3_8_"$type1"_DMGs_vs_"$type1"_orfs_sort.identifier"

cat "Step3_8_"$type1"_DMGs_vs_"$type1"_orfs_sort.identifier" | awk '{print $1}' >> "Step3_4_"$type1"_DMGs.identifier"

#clean up temporary files

rm -f "Step3_4_"$type1"_DMGs_tmp.identifier" "Step3_5_"$type1"_DMGs_tmp.fasta" "Step3_8_"$type1"_DMGs_vs_"$type1"_orfs_tmp.identifier" "Step3_8_"$type1"_DMGs_vs_"$type1"_orfs_tmp_sort_wc.identifier" cat "Step3_8_"$type1"_DMGs_vs_"$type1"_orfs_sort_blocks.identifier" "Step3_8_"$type1"_DMGs_vs_"$type1"_orfs_sort_no_blocks.identifier" ID_count.txt


if $protein_level
	then
	#get fasta-sequences of DMG orfs_aa of type 1 filtered according to min_DMG_occurrence

	get_fasta "Step3_4_"$type1"_DMGs.identifier" $type1"_orfs_aa" "Step3_5_"$type1"_DMGs.fasta"

	#blastp type1 DMGs filtered according to min_DMG_occurrence versus type1 orfs of single members

	for blast_db in $type1_dbname_list
		do
		#split fasta files for multiprocessing

		cat "Step3_5_"$type1"_DMGs.fasta" > split_input.fasta
		seq_num=`grep -c ">" split_input.fasta`
	if [[ $num_blast_proc -gt $seq_num ]]
		then
		num_blast_proc=1
		else
		num_blast_proc=$set_num_blast_proc
	fi
		split_at_num=$(( seq_num/num_blast_proc ))
		awk -v split_at_num=$split_at_num -v fastafilebasename="seq_split" 'BEGIN {n_seq=0;} /^>/ {if(n_seq%split_at_num==0){fastafile=sprintf(fastafilebasename"%d.fasta",n_seq);} print >> fastafile; n_seq++; next;} { print >> fastafile; }' < split_input.fasta

		#perform blast

		query_num=1
		for queryfiles in ./seq_split*".fasta"
			do		
			$blastbin_path/blastp -db $blast_db"_orfs_aa" -query $queryfiles -outfmt "6 qseqid sseqid qlen slen pident length evalue" -max_target_seqs 500 -num_threads 4 -task blastp | awk -v blastp_within_group_qscov=$blastp_within_group_qscov -v blastp_perc_identity_cut=$blastp_perc_identity_cut -v blastp_e_value=$blastp_e_value '{if ($6/$3 >= blastp_within_group_qscov && $6/$4 >= blastp_within_group_qscov && $5 >= blastp_perc_identity_cut && $7 <= blastp_e_value) print $0}' > "seq_split_"$query_num".blast" &
			query_num=$(( query_num+1 ))	
		done
		wait
		cat "seq_split_"*".blast" > "Step3_9_"$type1"_DMGs_vs_"$blast_db".blast"

		#clean up split files

		rm -f "seq_split_"*".blast"  "seq_split"*".fasta" split_input.fasta		

		#extract IDs

		cat "Step3_9_"$type1"_DMGs_vs_"$blast_db".blast" | awk '{print $2}' | sort | uniq | cut -d "|" -f 2 > "Step3_10_"$type1"_DMGs_vs_"$blast_db"_blast.identifier"
	done
else
	#get fasta-sequences of DMG orfs of type 1 filtered according to min_DMG_occurrence

	get_fasta "Step3_4_"$type1"_DMGs.identifier" $type1"_orfs" "Step3_5_"$type1"_DMGs.fasta"

	#megablast type1 DMGs filtered according to min_DMG_occurrence versus type1 orfs of single members

	for blast_db in $type1_dbname_list
		do
		#split fasta files for multiprocessing

		cat "Step3_5_"$type1"_DMGs.fasta" > split_input.fasta
		seq_num=`grep -c ">" split_input.fasta`
	if [[ $num_blast_proc -gt $seq_num ]]
		then
		num_blast_proc=1
		else
		num_blast_proc=$set_num_blast_proc
	fi
		split_at_num=$(( seq_num/num_blast_proc ))
		awk -v split_at_num=$split_at_num -v fastafilebasename="seq_split" 'BEGIN {n_seq=0;} /^>/ {if(n_seq%split_at_num==0){fastafile=sprintf(fastafilebasename"%d.fasta",n_seq);} print >> fastafile; n_seq++; next;} { print >> fastafile; }' < split_input.fasta

		#perform blast

		query_num=1
		for queryfiles in ./seq_split*".fasta"
			do		
			$blastbin_path/blastn -db $blast_db -query $queryfiles -outfmt "6 qseqid sseqid qlen slen pident length evalue" -max_target_seqs 500 -num_threads 4 -task $mb_task | awk -v megablast_within_group_qscov=$megablast_within_group_qscov -v megablast_perc_identity_cut=$megablast_perc_identity_cut -v megablast_e_value=$megablast_e_value '{if ($6/$3 >= megablast_within_group_qscov && $6/$4 >= megablast_within_group_qscov && $5 >= megablast_perc_identity_cut && $7 <= megablast_e_value) print $0}' > "seq_split_"$query_num".blast" &
			query_num=$(( query_num+1 ))	
		done
		wait
		cat "seq_split_"*".blast" > "Step3_9_"$type1"_DMGs_vs_"$blast_db".blast"

		#clean up split files

		rm -f "seq_split_"*".blast"  "seq_split"*".fasta" split_input.fasta		

		#extract IDs

		cat "Step3_9_"$type1"_DMGs_vs_"$blast_db".blast" | awk '{print $2}' | sort | uniq | cut -d "|" -f 2 > "Step3_10_"$type1"_DMGs_vs_"$blast_db"_blast.identifier"
	done

fi

#get IDs of DMG orfs of type 1 not present in genome of type 2 and filtered according to min_DMG_occurrence : Frequency

headerstring="Orf_ID"
num_db=1
for blast_db in $type1_dbname_list
	do
	headerstring="$headerstring\t$blast_db"
done
echo -e $headerstring > "Step3_11_"$type1"_DMGs_tmp.frequency"

get_frequency_distribution "Step3_8_"$type1"_DMGs_vs_"$type1"_orfs_sort.identifier" "Step3_10_"$type1"_DMGs_vs_" "Step3_11_"$type1"_DMGs_tmp.frequency" true

echo -e $headerstring > "Step3_11_"$type1"_DMGs.frequency"

cat "Step3_11_"$type1"_DMGs_tmp.frequency" | grep -Fv "Orf_ID" | awk '{
	occurrence=$2;
	out=$2
	for(i=3; i<=NF; i++) {
	occurrence=occurrence+$i
	out=out"\t"$i
		};

	print occurrence "\t" $1 "\t" out;
	
	}' | sort -k2,2 -k1nr | cut -d"	" -f2-| awk '$1!=p{print;p=$1}'  >> "Step3_11_"$type1"_DMGs.frequency"

#get IDs of DMG orfs of type 1 not present in genome of type 2 and filtered according to min_DMG_occurrence : Occurrence

echo -e $headerstring > "Step3_11_"$type1"_DMGs_tmp.distribution"

get_frequency_distribution "Step3_8_"$type1"_DMGs_vs_"$type1"_orfs_sort.identifier" "Step3_10_"$type1"_DMGs_vs_" "Step3_11_"$type1"_DMGs_tmp.distribution" false

echo -e $headerstring > "Step3_11_"$type1"_DMGs.distribution"

cat "Step3_11_"$type1"_DMGs_tmp.distribution" | grep -Fv "Orf_ID" | awk '{
	occurrence=$2;
	out=$2
	for(i=3; i<=NF; i++) {
	occurrence=occurrence+$i
	out=out"\t"$i
		};

	print occurrence "\t" $1 "\t" out;
	
	}' | sort -k2,2 -k1nr | cut -d"	" -f2-| awk '$1!=p{print;p=$1}'  >> "Step3_11_"$type1"_DMGs.distribution"

#clean up

rm -f "Step3_11_"$type1"_DMGs_tmp.frequency" "Step3_11_"$type1"_DMGs_tmp.distribution"

#sort according to DMG_occurrence - descending

cat "Step3_11_"$type1"_DMGs.distribution" | grep -Fv "Orf_ID" | awk '{
occurrence=$2;
out=$2
for(i=3; i<=NF; i++) {
occurrence=occurrence+$i
out=out"\t"$i
	};

print $1 "\t" occurrence "\t" out;
	
}' | sort -r -k 2  | uniq > "Step3_12_"$type1"_DMGs_tmp.distribution"

headerstring="Orf_ID\tSum"
num_db=1
for blast_db in $type1_dbname_list
	do
	headerstring="$headerstring\t$blast_db"
done
echo -e $headerstring > "Step3_12_"$type1"_DMGs_sort.header"
cat "Step3_12_"$type1"_DMGs_sort.header" "Step3_12_"$type1"_DMGs_tmp.distribution" > "Step3_12_"$type1"_DMGs_sort.distribution" 
rm -f "Step3_12_"$type1"_DMGs_sort.header" "Step3_12_"$type1"_DMGs_tmp.distribution"

#get sequence IDs of DMG orfs of type 1 genome filtered, min_DMG_occurrence filtered and sorted

cat "Step3_12_"$type1"_DMGs_sort.distribution" | grep -Fv "Orf_ID" | awk '{
print $1;
}' | sort -u > "Step3_13_"$type1"_DMGs_sort.identifier"

if $protein_level
	then
	#get fasta-sequences of DMG orfs_aa of type 1 genome filtered, min_DMG_occurrence filtered and sorted

	get_fasta "Step3_13_"$type1"_DMGs_sort.identifier" $type1"_orfs_aa" "Step3_14_"$type1"_DMGs_final_aa.fasta"

	#get fasta-sequences of DMG orfs of type 1 genome filtered, min_DMG_occurrence filtered and sorted

	get_fasta "Step3_13_"$type1"_DMGs_sort.identifier" $type1"_orfs" "Step3_14_"$type1"_DMGs_final.fasta"

else

	#get fasta-sequences of DMG orfs of type 1 genome filtered, min_DMG_occurrence filtered and sorted

	get_fasta "Step3_13_"$type1"_DMGs_sort.identifier" $type1"_orfs" "Step3_14_"$type1"_DMGs_final.fasta"
fi

#display number of DMGs after Step 3

num_DMGs_nblast=$(cat "Step3_13_"$type1"_DMGs_sort.identifier" | wc -l )
echo -e "Number of DMGs after occurrence filter: $num_DMGs_nblast."

#check if number of blast processes has to be reduced

if [[ $num_blast_proc -gt $num_DMGs_nblast ]]
	then
	num_blast_proc=1
	else
	num_blast_proc=$set_num_blast_proc
fi


###################################################################################################################################################################################################

#Step 4 - DC-Filter - check type1 DMG sequences with discontiguous megablast, used to find more distant (e.g., interspecies) sequences

if $dc_filter
	then

	echo
	echo -e "#######################################################################"
	echo -e "Step 4 of $numsteps:  DC-MEGABLAST $type1 DMGs vs $type2 genomes - DC filter $type1 DMGs"
	echo


	#get fasta-sequences of DMG orfs of type 1 filtered according to min_DMG_occurrence

	get_fasta "Step3_4_"$type1"_DMGs.identifier" $type1"_orfs" "Step4_1_"$type1"_DMGs.fasta"
	
	#dcblast type 1 DMGs versus type2_genomes
	
	#split fasta files for multiprocessing

	cat "Step4_1_"$type1"_DMGs.fasta" > split_input.fasta
	seq_num=`grep -c ">" split_input.fasta`
	if [[ $num_blast_proc -gt $seq_num ]]
		then
		num_blast_proc=1
		else
		num_blast_proc=$set_num_blast_proc
	fi
	split_at_num=$(( seq_num/num_blast_proc ))
	awk -v split_at_num=$split_at_num -v fastafilebasename="seq_split" 'BEGIN {n_seq=0;} /^>/ {if(n_seq%split_at_num==0){fastafile=sprintf(fastafilebasename"%d.fasta",n_seq);} print >> fastafile; n_seq++; next;} { print >> fastafile; }' < split_input.fasta

	#perform blast

	query_num=1
	for queryfiles in ./seq_split*".fasta"
		do
		$blastbin_path/blastn -db $type2"_genomes" -query $queryfiles -outfmt "6 qseqid sseqid qlen pident length evalue" -max_target_seqs 500 -num_threads 4  -task dc-megablast | awk -v dc_between_group_qscov=$dc_between_group_qscov -v dc_perc_identity_cut=$dc_perc_identity_cut -v dc_blast_e_value=$dc_blast_e_value '{if ($5/$3 >= dc_between_group_qscov && $4 >= dc_perc_identity_cut && $6 <= dc_blast_e_value) print $0}'> "seq_split_"$query_num".blast" &
		query_num=$(( query_num+1 ))	
	done
	wait
	cat "seq_split_"*".blast" > "Step4_2_"$type1"_DMGs_vs_"$type2"_genomes_dc.blast"

	#clean up split files

	rm -f "seq_split_"*".blast"  "seq_split"*".fasta" split_input.fasta
	#get sequence IDs of type 1 of dc-megablast hits only

	cat "Step4_2_"$type1"_DMGs_vs_"$type2"_genomes_dc.blast" | awk '{print $1}' | sort | uniq | cut -d "|" -f 2 > "Step4_3_"$type1"_DMGs_vs_"$type2"_genomes_dc.identifier"

	#get DMG orf IDs of type 1 filtered with dc-megablast

	grep -Fxv -f "Step4_3_"$type1"_DMGs_vs_"$type2"_genomes_dc.identifier" "Step3_4_"$type1"_DMGs.identifier" > "Step4_4_"$type1"_DMGs.identifier"

	#check if DMGs remain after dc filter - if not proceed with next type-combination

	if [[ ! -s "Step4_4_"$type1"_DMGs.identifier" ]]
		then
			echo -e "Error - Step 5 of $numsteps cant be performed - No input from Step 4" >&2
			cd $BADGE_path			
			return 1
	fi

	#get fasta-sequences of type 1 DMG orfs filtered with dc-megablast

	get_fasta "Step4_4_"$type1"_DMGs.identifier" $type1"_orfs" "Step4_5_"$type1"_DMGs.fasta"

	#megablast type1 DMG orfs dc-megablast blast filtered versus type1 orfs - preperation to get occurrence, distribution and frequency files
	
	#split fasta files for multiprocessing

	cat "Step4_5_"$type1"_DMGs.fasta" > split_input.fasta
	seq_num=`grep -c ">" split_input.fasta`
	if [[ $num_blast_proc -gt $seq_num ]]
		then
		num_blast_proc=1
		else
		num_blast_proc=$set_num_blast_proc
	fi
	split_at_num=$(( seq_num/num_blast_proc ))
	awk -v split_at_num=$split_at_num -v fastafilebasename="seq_split" 'BEGIN {n_seq=0;} /^>/ {if(n_seq%split_at_num==0){fastafile=sprintf(fastafilebasename"%d.fasta",n_seq);} print >> fastafile; n_seq++; next;} { print >> fastafile; }' < split_input.fasta

	#perform blast

	query_num=1
	for queryfiles in ./seq_split*".fasta"
		do
		$blastbin_path/blastn -db $type1"_orfs" -query $queryfiles -outfmt "6 qseqid sseqid qlen slen pident length evalue" -max_target_seqs 500 -num_threads 4 -task $mb_task |  awk -v megablast_within_group_qscov=$megablast_within_group_qscov -v megablast_perc_identity_cut=$megablast_perc_identity_cut -v megablast_e_value=$megablast_e_value '{if ($6/$3 >= megablast_within_group_qscov && $6/$4 >= megablast_within_group_qscov && $5 >= megablast_perc_identity_cut && $7 <= megablast_e_value) print $0}' > "seq_split_"$query_num".blast" &
		query_num=$(( query_num+1 ))	
	done
	wait
	cat "seq_split_"*".blast" > "Step4_6_"$type1"_DMGs_vs_"$type1"_orfs.blast"

	#clean up split files

	rm -f "seq_split_"*".blast"  "seq_split"*".fasta" split_input.fasta
	#sequences from different genomes of type1 - one file for each genome

	if [[ $num_single_db -gt 1 ]]
		then

		for blast_db in $type1_dbname_list
			do
			grep -Fx -f $type1"_"$blast_db"_orfs.identifier" "Step4_4_"$type1"_DMGs.identifier" > "Step4_7_"$type1"_DMGs_"$blast_db".identifier"
			get_fasta "Step4_7_"$type1"_DMGs_"$blast_db".identifier" $blast_db "Step4_8_"$type1"_DMGs_"$blast_db".fasta"		
		done
	fi

	#remove lcl| tag from header ID

	cat "Step4_6_"$type1"_DMGs_vs_"$type1"_orfs.blast" | cut -d "|" -f 2 > "Step4_9_"$type1"_DMGs_vs_"$type1"_orfs.blast"

	#put all sequence IDs matching the same DMG sequence in one line (not ordered yet)

	cat "Step4_9_"$type1"_DMGs_vs_"$type1"_orfs.blast" | awk '{
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
	END{print prev " " outstring;}' > "Step4_10_"$type1"_DMGs_vs_"$type1"_orfs.identifier"

	#order sequence IDs in all lines

	while read line
		do
	  	#echo $ID
		echo $line | xargs -n1 | sort -u | xargs >> "Step4_11_"$type1"_DMGs_vs_"$type1"_orfs_tmp.identifier"
	done < "Step4_10_"$type1"_DMGs_vs_"$type1"_orfs.identifier"

	#remove duplicates

	cat "Step4_11_"$type1"_DMGs_vs_"$type1"_orfs_tmp.identifier" | awk '{ print NF, $0 }' | sort -k2,2 -k1nr | cut -d" " -f2-| awk '$1!=p{print;p=$1}' > "Step4_11_"$type1"_DMGs_vs_"$type1"_orfs_sort.identifier"

	#clean up temporary files

	rm -f "Step4_11_"$type1"_DMGs_vs_"$type1"_orfs_tmp.identifier"

	#megablast type1 DMGs filtered according to dc filter versus type1 orfs of single members

	for blast_db in $type1_dbname_list
		do
		#split fasta files for multiprocessing

		cat "Step4_5_"$type1"_DMGs.fasta" > split_input.fasta
		seq_num=`grep -c ">" split_input.fasta`
	if [[ $num_blast_proc -gt $seq_num ]]
		then
		num_blast_proc=1
		else
		num_blast_proc=$set_num_blast_proc
	fi
		split_at_num=$(( seq_num/num_blast_proc ))
		awk -v split_at_num=$split_at_num -v fastafilebasename="seq_split" 'BEGIN {n_seq=0;} /^>/ {if(n_seq%split_at_num==0){fastafile=sprintf(fastafilebasename"%d.fasta",n_seq);} print >> fastafile; n_seq++; next;} { print >> fastafile; }' < split_input.fasta

		#perform blast

		query_num=1
		for queryfiles in ./seq_split*".fasta"
			do		
			$blastbin_path/blastn -db $blast_db -query $queryfiles -outfmt "6 qseqid sseqid qlen slen pident length evalue" -max_target_seqs 500 -num_threads 4 -task $mb_task | awk -v megablast_within_group_qscov=$megablast_within_group_qscov -v megablast_perc_identity_cut=$megablast_perc_identity_cut -v megablast_e_value=$megablast_e_value '{if ($6/$3 >= megablast_within_group_qscov && $6/$4 >= megablast_within_group_qscov && $5 >= megablast_perc_identity_cut && $7 <= megablast_e_value) print $0}' > "seq_split_"$query_num".blast" &
			query_num=$(( query_num+1 ))	
		done
		wait
		cat "seq_split_"*".blast" > "Step4_12_"$type1"_DMGs_"$min_DMG_occurrence"_genomes_filtered_dc_megablast_vs_"$blast_db".blast"

		#clean up split files

		rm -f "seq_split_"*".blast"  "seq_split"*".fasta" split_input.fasta			

		#extract IDs

		cat "Step4_12_"$type1"_DMGs_"$min_DMG_occurrence"_genomes_filtered_dc_megablast_vs_"$blast_db".blast" | awk '{print $2}' | sort | uniq | cut -d "|" -f 2 > "Step4_12_"$type1"_DMGs_vs_"$blast_db"_blast.identifier"
	done

	#get IDs of DMG orfs of type 1 not present in genome of type 2 and filtered according to dc filter : Frequency

	headerstring="Orf_ID"
	num_db=1
	for blast_db in $type1_dbname_list
		do
		headerstring="$headerstring\t$blast_db"
	done
	echo -e $headerstring > "Step4_13_"$type1"_DMGs_tmp.frequency"
	
	get_frequency_distribution "Step4_11_"$type1"_DMGs_vs_"$type1"_orfs_sort.identifier" "Step4_12_"$type1"_DMGs_vs_" "Step4_13_"$type1"_DMGs_tmp.frequency" true

	echo -e $headerstring > "Step4_13_"$type1"_DMGs.frequency"

	cat "Step4_13_"$type1"_DMGs_tmp.frequency" | grep -Fv "Orf_ID" | awk '{
	occurrence=$2;
	out=$2
	for(i=3; i<=NF; i++) {
	occurrence=occurrence+$i
	out=out"\t"$i
		};

	print occurrence "\t" $1 "\t" out;
	
	}' | sort -k2,2 -k1nr | cut -d"	" -f2-| awk '$1!=p{print;p=$1}'  >> "Step4_13_"$type1"_DMGs.frequency"

	#get IDs of DMG orfs of type 1 not present in genome of type 2 and filtered according to dc filter : Occurrence

	echo -e $headerstring > "Step4_14_"$type1"_DMGs_tmp.distribution"
	
	get_frequency_distribution "Step4_11_"$type1"_DMGs_vs_"$type1"_orfs_sort.identifier" "Step4_12_"$type1"_DMGs_vs_" "Step4_14_"$type1"_DMGs_tmp.distribution" false

	echo -e $headerstring > "Step4_14_"$type1"_DMGs.distribution"

	cat "Step4_14_"$type1"_DMGs_tmp.distribution" | grep -Fv "Orf_ID" | awk '{
	occurrence=$2;
	out=$2
	for(i=3; i<=NF; i++) {
	occurrence=occurrence+$i
	out=out"\t"$i
		};

	print occurrence "\t" $1 "\t" out;
	
	}' | sort -k2,2 -k1nr | cut -d"	" -f2-| awk '$1!=p{print;p=$1}'  >> "Step4_14_"$type1"_DMGs.distribution"

	#clean up

	rm -f "Step4_13_"$type1"_DMGs_tmp.frequency" "Step4_14_"$type1"_DMGs_tmp.distribution"

	#sort according to DMG_occurrence - descending

	cat "Step4_14_"$type1"_DMGs.distribution" | grep -Fv "Orf_ID" | awk '{
	occurrence=$2;
	out=$2
	for(i=3; i<=NF; i++) {
	occurrence=occurrence+$i
	out=out"\t"$i
		};

	print $1 "\t" occurrence "\t" out;
	
	}' | sort -r -k 2  | uniq > "Step4_15_"$type1"_DMGs_tmp.distribution"

	headerstring="Orf_ID\tSum"
	num_db=1
	for blast_db in $type1_dbname_list
		do
		headerstring="$headerstring\t$blast_db"
	done
	echo -e $headerstring > "Step4_15_"$type1"_DMGs_occurrence_sort_header_tmp.txt"
	cat "Step4_15_"$type1"_DMGs_occurrence_sort_header_tmp.txt" "Step4_15_"$type1"_DMGs_tmp.distribution" > "Step4_15_"$type1"_DMGs_sort.distribution"
	 
	rm -f "Step4_15_"$type1"_DMGs_occurrence_sort_header_tmp.txt" "Step4_15_"$type1"_DMGs_tmp.distribution"

	#get sequence IDs of DMG orfs of type 1 genome filtered, min_DMG_occurrence filtered, dc filtered and sorted

	cat "Step4_15_"$type1"_DMGs_sort.distribution" | grep -Fv "Orf_ID" | awk '{
	print $1;
	}' | sort -u > "Step4_16_"$type1"_DMGs_sort.identifier"

	#get fasta-sequences of DMG orfs of type 1 genome filtered, min_DMG_occurrence filtered, dc filtered and sorted

	get_fasta "Step4_16_"$type1"_DMGs_sort.identifier" $type1"_orfs" "Step4_17_"$type1"_DMGs_final.fasta"

	#display number of DMGs after Step 4	

	num_DMGs_dc_megablast=$(cat "Step4_16_"$type1"_DMGs_sort.identifier" | wc -l )
	echo -e "Number of DMGs after dc_megablast filter: $num_DMGs_dc_megablast."

	#check if number of blast processes has to be reduced

	if [[ $num_blast_proc -gt $num_DMGs_dc_megablast ]]
		then
		num_blast_proc=1
		else
		num_blast_proc=$set_num_blast_proc
	fi

	##################################################################################################################################
	#get sequences of unique orfs of type 1 filtered after dc-filter for Step 5 (blastn hits filter)

	get_fasta "Step4_16_"$type1"_DMGs_sort.identifier" $type1"_orfs" "Step5_1_"$type1"_DMGs.fasta"
	cp "Step4_16_"$type1"_DMGs_sort.identifier" "Step5_1_"$type1"_DMGs.identifier"

else

	echo
	echo -e "#######################################################################"
	echo -e "Step 4 of $numsteps is skipped:  DC-filter not active"
	echo

	#get sequences of unique orfs of type 1 filtered before dc-filter for Step 5 (blastn hits filter)

	get_fasta "Step3_4_"$type1"_DMGs.identifier" $type1"_orfs" "Step5_1_"$type1"_DMGs.fasta"
	cp "Step3_4_"$type1"_DMGs.identifier" "Step5_1_"$type1"_DMGs.identifier"
fi

###################################################################################################################################################################################################

#Step 5 - Blastn Filter - to identify those DMGs, which have a blastn hits in type2_genomes (partitially identical sequences)

if $blastn_filter
	then
	
	echo
	echo -e "#######################################################################"
	echo -e "Step 5 of $numsteps:  BLASTN $type1 DMGs vs $type2 genome sequences - BLASTN filter $type1 DMGs"
	echo
	
	#blastn type 1 DMGs versus type2_genomes 
	
	#split fasta files for multiprocessing

	cat "Step5_1_"$type1"_DMGs.fasta" > split_input.fasta
	seq_num=`grep -c ">" split_input.fasta`
	if [[ $num_blast_proc -gt $seq_num ]]
		then
		num_blast_proc=1
		else
		num_blast_proc=$set_num_blast_proc
	fi
	split_at_num=$(( seq_num/num_blast_proc ))
	awk -v split_at_num=$split_at_num -v fastafilebasename="seq_split" 'BEGIN {n_seq=0;} /^>/ {if(n_seq%split_at_num==0){fastafile=sprintf(fastafilebasename"%d.fasta",n_seq);} print >> fastafile; n_seq++; next;} { print >> fastafile; }' < split_input.fasta

	#perform blast

	query_num=1
	for queryfiles in ./seq_split*".fasta"
		do
	$blastbin_path/blastn -db $type2"_genomes" -query $queryfiles -outfmt "6 qseqid sseqid qlen pident length evalue qstart qend sstart send" -max_target_seqs 500 -num_threads 4 -task blastn -word_size 7 | awk -v blastn_between_group_qscov=$blastn_between_group_qscov -v blastn_e_value=$blastn_e_value -v blastn_perc_identity_cut=$blastn_perc_identity_cut '{if ($5/$3 >= blastn_between_group_qscov && $4 >= blastn_perc_identity_cut && $6 <= blastn_e_value) print $0}' > "seq_split_"$query_num".blast" &
	query_num=$(( query_num+1 ))	
	done
	wait
	cat "seq_split_"*".blast" > "Step5_2_"$type1"_DMGs_vs_"$type2"_genomes_blastn.blast"

	#clean up split files

	rm -f "seq_split_"*".blast"  "seq_split"*".fasta" split_input.fasta
	
	#get IDs of type 1 orfs with partitially identical sequences in type 2 genomes

	cat "Step5_2_"$type1"_DMGs_vs_"$type2"_genomes_blastn.blast" | awk '{print $1}' | sort | uniq | cut -d "|" -f 2 > "Step5_3_"$type1"_DMGs_vs_"$type2"_genomes_blastn.identifier"

	#get IDs of type 1 orfs with no hit in type 2 genomes

	grep -Fxv -f "Step5_3_"$type1"_DMGs_vs_"$type2"_genomes_blastn.identifier" "Step5_1_"$type1"_DMGs.identifier" > "Step5_4_"$type1"_DMGs.identifier"

	#get fasta-sequences of type 1 DMG orfs filtered with blastn hits filter

	get_fasta "Step5_4_"$type1"_DMGs.identifier" $type1"_orfs" "Step5_5_"$type1"_DMGs.fasta"

	#megablast type1 DMGs orfs blastn hits filtered versus type1 orfs

	#split fasta files for multiprocessing

	cat "Step5_5_"$type1"_DMGs.fasta" > split_input.fasta
	seq_num=`grep -c ">" split_input.fasta`
	if [[ $num_blast_proc -gt $seq_num ]]
		then
		num_blast_proc=1
		else
		num_blast_proc=$set_num_blast_proc
	fi
	split_at_num=$(( seq_num/num_blast_proc ))
	awk -v split_at_num=$split_at_num -v fastafilebasename="seq_split" 'BEGIN {n_seq=0;} /^>/ {if(n_seq%split_at_num==0){fastafile=sprintf(fastafilebasename"%d.fasta",n_seq);} print >> fastafile; n_seq++; next;} { print >> fastafile; }' < split_input.fasta

	#perform blast

	query_num=1
	for queryfiles in ./seq_split*".fasta"
		do
	$blastbin_path/blastn -db $type1"_orfs" -query $queryfiles -outfmt "6 qseqid sseqid qlen slen pident length evalue" -max_target_seqs 500 -num_threads 4 -task $mb_task |  awk -v megablast_within_group_qscov=$megablast_within_group_qscov -v megablast_perc_identity_cut=$megablast_perc_identity_cut -v megablast_e_value=$megablast_e_value '{if ($6/$3 >= megablast_within_group_qscov && $6/$4 >= megablast_within_group_qscov && $5 >= megablast_perc_identity_cut && $7 <= megablast_e_value) print $0}' > "seq_split_"$query_num".blast" &
	query_num=$(( query_num+1 ))	
	done
	wait
	cat "seq_split_"*".blast" > "Step5_6_"$type1"_DMGs_vs_"$type1"_orfs.blast"

	#clean up split files

	rm -f "seq_split_"*".blast"  "seq_split"*".fasta" split_input.fasta
	
	#sequences from different genomes of type1 one file for each genome

	num_single_db=`echo $type1_dbname_list | wc -w`

	if [[ $num_single_db -gt 1 ]]
		then

		for blast_db in $type1_dbname_list
			do
			grep -Fx -f $type1"_"$blast_db"_orfs.identifier" "Step5_4_"$type1"_DMGs.identifier" > "Step5_7_"$type1"_DMGs_"$blast_db".identifier"
			get_fasta "Step5_7_"$type1"_DMGs_"$blast_db".identifier" $blast_db "Step5_8_"$type1"_DMGs_"$blast_db".fasta"			
		done
	fi

	#remove lcl| tag from header ID

	cat "Step5_6_"$type1"_DMGs_vs_"$type1"_orfs.blast" | cut -d "|" -f 2 > "Step5_9_"$type1"_DMGs_vs_"$type1"_orfs.blast"

	#put all sequence IDs matching the same DMG sequence in one line (not ordered yet)

	cat "Step5_9_"$type1"_DMGs_vs_"$type1"_orfs.blast" | awk '{
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
	END{print prev " " outstring;}' > "Step5_10_"$type1"_DMGs_vs_"$type1"_orfs.identifier"

	#order sequence IDs in all lines

	while read line
		do
	  	#echo $ID
		echo $line | xargs -n1 | sort -u | xargs >> "Step5_11_"$type1"_DMGs_vs_"$type1"_orfs_tmp.identifier"
	done < "Step5_10_"$type1"_DMGs_vs_"$type1"_orfs.identifier"

	#remove duplicates

	cat "Step5_11_"$type1"_DMGs_vs_"$type1"_orfs_tmp.identifier" | awk '{ print NF, $0 }' | sort -k2,2 -k1nr | cut -d" " -f2-| awk '$1!=p{print;p=$1}' > "Step5_11_"$type1"_DMGs_vs_"$type1"_orfs_sort.identifier"

	#clean up temporary files

	rm -f "Step5_11_"$type1"_DMGs_vs_"$type1"_orfs_tmp.identifier"


	#megablast type1 DMGs filtered according to blastn_hits filter versus type1 orfs of single members

	for blast_db in $type1_dbname_list
		do
		#split fasta files for multiprocessing

		cat "Step5_5_"$type1"_DMGs.fasta" > split_input.fasta
		seq_num=`grep -c ">" split_input.fasta`
	if [[ $num_blast_proc -gt $seq_num ]]
		then
		num_blast_proc=1
		else
		num_blast_proc=$set_num_blast_proc
	fi
		split_at_num=$(( seq_num/num_blast_proc ))
		awk -v split_at_num=$split_at_num -v fastafilebasename="seq_split" 'BEGIN {n_seq=0;} /^>/ {if(n_seq%split_at_num==0){fastafile=sprintf(fastafilebasename"%d.fasta",n_seq);} print >> fastafile; n_seq++; next;} { print >> fastafile; }' < split_input.fasta

		#perform blast

		query_num=1
		for queryfiles in ./seq_split*".fasta"
			do		
			$blastbin_path/blastn -db $blast_db -query $queryfiles -outfmt "6 qseqid sseqid qlen slen pident length evalue" -max_target_seqs 500 -num_threads 4 -task $mb_task | awk -v megablast_within_group_qscov=$megablast_within_group_qscov -v megablast_perc_identity_cut=$megablast_perc_identity_cut -v megablast_e_value=$megablast_e_value '{if ($6/$3 >= megablast_within_group_qscov && $6/$4 >= megablast_within_group_qscov && $5 >= megablast_perc_identity_cut && $7 <= megablast_e_value) print $0}' > "seq_split_"$query_num".blast" &
			query_num=$(( query_num+1 ))	
		done
		wait
		cat "seq_split_"*".blast" > "Step5_12_"$type1"_DMGs_vs_"$blast_db".blast"

		#clean up split files

		rm -f "seq_split_"*".blast"  "seq_split"*".fasta" split_input.fasta	
	
		#extract IDs

		cat "Step5_12_"$type1"_DMGs_vs_"$blast_db".blast" | awk '{print $2}' | sort | uniq | cut -d "|" -f 2 > "Step5_12_"$type1"_DMGs_vs_"$blast_db"_blast.identifier"
	done

	#get IDs of DMG orfs of type 1 not present in genome of type 2 and filtered according to blastn_hits : Frequency

	headerstring="Orf_ID"
	num_db=1
	for blast_db in $type1_dbname_list
		do
		headerstring="$headerstring\t$blast_db"
	done
	echo -e $headerstring > "Step5_13_"$type1"_DMGs_tmp.frequency"

	get_frequency_distribution "Step5_11_"$type1"_DMGs_vs_"$type1"_orfs_sort.identifier" "Step5_12_"$type1"_DMGs_vs_" "Step5_13_"$type1"_DMGs_tmp.frequency" true

	echo -e $headerstring > "Step5_13_"$type1"_DMGs.frequency"

	cat "Step5_13_"$type1"_DMGs_tmp.frequency" | grep -Fv "Orf_ID" | awk '{
	occurrence=$2;
	out=$2
	for(i=3; i<=NF; i++) {
	occurrence=occurrence+$i
	out=out"\t"$i
		};

	print occurrence "\t" $1 "\t" out;
	
	}' | sort -k2,2 -k1nr | cut -d"	" -f2-| awk '$1!=p{print;p=$1}'  >> "Step5_13_"$type1"_DMGs.frequency"

	#get IDs of DMG orfs of type 1 not present in genome of type 2 and filtered according to blastn_hits : Occurrence

	echo -e $headerstring > "Step5_14_"$type1"_DMGs_tmp.distribution"
	
	get_frequency_distribution "Step5_11_"$type1"_DMGs_vs_"$type1"_orfs_sort.identifier" "Step5_12_"$type1"_DMGs_vs_" "Step5_14_"$type1"_DMGs_tmp.distribution" false

	echo -e $headerstring > "Step5_14_"$type1"_DMGs.distribution"

	cat "Step5_14_"$type1"_DMGs_tmp.distribution" | grep -Fv "Orf_ID" | awk '{
	occurrence=$2;
	out=$2
	for(i=3; i<=NF; i++) {
	occurrence=occurrence+$i
	out=out"\t"$i
		};

	print occurrence "\t" $1 "\t" out;
	
	}' | sort -k2,2 -k1nr | cut -d"	" -f2-| awk '$1!=p{print;p=$1}'  >> "Step5_14_"$type1"_DMGs.distribution"

	#clean up

	rm -f "Step5_13_"$type1"_DMGs_tmp.frequency" "Step5_14_"$type1"_DMGs_tmp.distribution"
	
	#sort according to DMG_occurrence - descending

	cat "Step5_14_"$type1"_DMGs.distribution" | grep -Fv "Orf_ID" | awk '{
	occurrence=$2;
	out=$2
	for(i=3; i<=NF; i++) {
	occurrence=occurrence+$i
	out=out"\t"$i
		};

	print $1 "\t" occurrence "\t" out;
	
	}' | sort -r -k 2  | uniq > "Step5_15_"$type1"_DMGs_tmp.distribution"

	headerstring="Orf_ID\tSum"
	num_db=1
	for blast_db in $type1_dbname_list
		do
		headerstring="$headerstring\t$blast_db"
	done
	echo -e $headerstring > "Step5_15_"$type1"_DMGs_occurrence_sort_header_tmp.txt"
	cat "Step5_15_"$type1"_DMGs_occurrence_sort_header_tmp.txt" "Step5_15_"$type1"_DMGs_tmp.distribution" > "Step5_15_"$type1"_DMGs_sort.distribution" 
	rm -f "Step5_15_"$type1"_DMGs_occurrence_sort_header_tmp.txt" "Step5_15_"$type1"_DMGs_tmp.distribution"

	#get sequence IDs of DMG orfs of type 1 genome filtered, min_DMG_occurrence filtered, dc filtered, blastn_hits filterd and sorted

	cat "Step5_15_"$type1"_DMGs_sort.distribution" | grep -Fv "Orf_ID" | awk '{
	print $1;
	}' | sort -u > "Step5_16_"$type1"_DMGs_sort.identifier"

	#get fasta-sequences of DMG orfs of type 1 genome filtered, min_DMG_occurrence filtered, dc filtered, blastn_hits filterd and sorted

	get_fasta "Step5_16_"$type1"_DMGs_sort.identifier" $type1"_orfs" "Step5_17_"$type1"_DMGs_final.fasta"	

	#display number of DMGs after Step 5

	num_DMGs_blastn_hits=$(cat "Step5_16_"$type1"_DMGs_sort.identifier" | wc -l )
	echo -e "Number of DMGs after blastn filter: $num_DMGs_blastn_hits."

	#check if number of blast processes has to be reduced

	if [[ $num_blast_proc -gt $num_DMGs_blastn_hits ]]
		then
		num_blast_proc=1
		else
		num_blast_proc=$set_num_blast_proc
	fi

##############################################################################################################################################################


else

	echo
	echo -e "#######################################################################"
	echo -e "Step 5 of $numsteps is skipped:  BLASTN filter not active"
	echo

	rm -f "Step5_1_"$type1"_DMGs.fasta"
	rm -f "Step5_1_"$type1"_DMGs.identifier"

fi

##############################################################################################################################################################

#Step 6 - Create final output & clean up (if selected)

echo
echo -e "#######################################################################"	
echo -e "Step 6 of $numsteps:  Create BADGE output"
echo

#create necessary files for master output file - fasta, identifier, distribution and blast files

if $blastn_filter
	then
	cp -f "Step5_17_"$type1"_DMGs_final.fasta" "Step6_1_"$type1"_DMGs.fasta"
	cp -f "Step5_11_"$type1"_DMGs_vs_"$type1"_orfs_sort.identifier" "Step6_1_"$type1"_DMGs_vs_"$type1"_orfs_sort.identifier"
	cp -f "Step5_14_"$type1"_DMGs.distribution" "Step6_1_"$type1"_DMGs.distribution"
	cp -f "Step5_14_"$type1"_DMGs.distribution" ".BADGE_"$type1"_DMGs.distribution"
	cp -f "Step5_13_"$type1"_DMGs.frequency" ".BADGE_"$type1"_DMGs.frequency"

elif $dc_filter
	then
	cp -f "Step4_17_"$type1"_DMGs_final.fasta" "Step6_1_"$type1"_DMGs.fasta"
	cp -f "Step4_11_"$type1"_DMGs_vs_"$type1"_orfs_sort.identifier" "Step6_1_"$type1"_DMGs_vs_"$type1"_orfs_sort.identifier"
	cp -f "Step4_14_"$type1"_DMGs.distribution" "Step6_1_"$type1"_DMGs.distribution"
	cp -f "Step4_14_"$type1"_DMGs.distribution" ".BADGE_"$type1"_DMGs.distribution"
	cp -f "Step4_13_"$type1"_DMGs.frequency" ".BADGE_"$type1"_DMGs.frequency"
else
	cp -f "Step3_14_"$type1"_DMGs_final.fasta" "Step6_1_"$type1"_DMGs.fasta"
	cp -f "Step3_8_"$type1"_DMGs_vs_"$type1"_orfs_sort.identifier" "Step6_1_"$type1"_DMGs_vs_"$type1"_orfs_sort.identifier"
	cp -f "Step3_11_"$type1"_DMGs.distribution" "Step6_1_"$type1"_DMGs.distribution"
	cp -f "Step3_11_"$type1"_DMGs.distribution" ".BADGE_"$type1"_DMGs.distribution"
	cp -f "Step3_11_"$type1"_DMGs.frequency" ".BADGE_"$type1"_DMGs.frequency"
	if $protein_level
		then
		cp -f "Step3_14_"$type1"_DMGs_final_aa.fasta" "Step6_1_"$type1"_DMGs_aa.fasta"
	fi
fi

#prepare identifier file for get fasta-sequences command (blastdbcmd batch_entry)

cat "Step6_1_"$type1"_DMGs_vs_"$type1"_orfs_sort.identifier" | xargs -n1 >> "Step6_1_"$type1"_DMGs_vs_"$type1"_orfs_sort_single_column.identifier"
rm -f "Step6_1_"$type1"_DMGs_vs_"$type1"_orfs_sort_tmp.identifier"

#get fasta-sequences of all representatives of each DMG orf of type 1 - as orfs

get_fasta "Step6_1_"$type1"_DMGs_vs_"$type1"_orfs_sort_single_column.identifier" $type1"_orfs" "Step6_3_"$type1"_DMGs.fasta"

#split fasta files for multiprocessing

cat "Step6_1_"$type1"_DMGs.fasta" > split_input.fasta
seq_num=`grep -c ">" split_input.fasta`
if [[ $num_blast_proc -gt $seq_num ]]
	then
	num_blast_proc=1
	else
	num_blast_proc=$set_num_blast_proc
fi
split_at_num=$(( seq_num/num_blast_proc ))
awk -v split_at_num=$split_at_num -v fastafilebasename="seq_split" 'BEGIN {n_seq=0;} /^>/ {if(n_seq%split_at_num==0){fastafile=sprintf(fastafilebasename"%d.fasta",n_seq);} print >> fastafile; n_seq++; next;} { print >> fastafile; }' < split_input.fasta

#perform blast

query_num=1
for queryfiles in ./seq_split*".fasta"
	do
	$blastbin_path/blastn -db $type2"_genomes" -query $queryfiles -task dc-megablast -outfmt "6 qseqid" > "seq_split_"$query_num".blast" &
	query_num=$(( query_num+1 ))	
done
wait
cat "seq_split_"*".blast" > "Step6_2_"$type1"_DMGs_dc.blast"

#clean up split files

rm -f "seq_split_"*".blast"  "seq_split"*".fasta" split_input.fasta

#split fasta files for multiprocessing

cat "Step6_1_"$type1"_DMGs.fasta" > split_input.fasta
seq_num=`grep -c ">" split_input.fasta`
if [[ $num_blast_proc -gt $seq_num ]]
	then
	num_blast_proc=1
	else
	num_blast_proc=$set_num_blast_proc
fi
split_at_num=$(( seq_num/num_blast_proc ))
awk -v split_at_num=$split_at_num -v fastafilebasename="seq_split" 'BEGIN {n_seq=0;} /^>/ {if(n_seq%split_at_num==0){fastafile=sprintf(fastafilebasename"%d.fasta",n_seq);} print >> fastafile; n_seq++; next;} { print >> fastafile; }' < split_input.fasta

#perform blast

query_num=1
for queryfiles in ./seq_split*".fasta"
	do
	$blastbin_path/blastn -db $type2"_genomes" -query $queryfiles -task blastn -outfmt "6 qseqid length" > "seq_split_"$query_num".blast" &
	query_num=$(( query_num+1 ))	
done
wait
cat "seq_split_"*".blast" > "Step6_2_"$type1"_DMGs_blastn.blast"

#clean up split files

rm -f "seq_split_"*".blast"  "seq_split"*".fasta" split_input.fasta

#get DMG sequence positions in genome (megablast does not find RAST "fix frameshift genes")

for blast_db in $type1_dbname_list_genome
	do
	#split fasta files for multiprocessing

	cat "Step6_3_"$type1"_DMGs.fasta" > split_input.fasta
	seq_num=`grep -c ">" split_input.fasta`
	if [[ $num_blast_proc -gt $seq_num ]]
		then
		num_blast_proc=1
		else
		num_blast_proc=$set_num_blast_proc
	fi
	split_at_num=$(( seq_num/num_blast_proc ))
	awk -v split_at_num=$split_at_num -v fastafilebasename="seq_split" 'BEGIN {n_seq=0;} /^>/ {if(n_seq%split_at_num==0){fastafile=sprintf(fastafilebasename"%d.fasta",n_seq);} print >> fastafile; n_seq++; next;} { print >> fastafile; }' < split_input.fasta

	#perform blast

	query_num=1
	for queryfiles in ./seq_split*".fasta"
		do	
		$blastbin_path/blastn -db $blast_db"_genome" -query $queryfiles -task $mb_task -perc_identity 100 -outfmt "6 qseqid sseqid sstart send qlen length" | awk '{if ($6/$5 >= 1) print $0}' | cut -d "|" -f 2 > "seq_split_"$query_num".blast" &
		query_num=$(( query_num+1 ))	
	done
	wait
	cat "seq_split_"*".blast" > "Step6_4_"$type1"_DMGs_vs_"$blast_db"_genome_tmp.blast"

	#clean up split files

	rm -f "seq_split_"*".blast"  "seq_split"*".fasta" split_input.fasta	
	
	#get position information	

	awk 'FNR==NR{a[$1];next};($1 in a)' $type1"_"$blast_db"_orfs.identifier" "Step6_4_"$type1"_DMGs_vs_"$blast_db"_genome_tmp.blast"  >> "Step6_4_"$type1"_DMGs_genome.blast"
	rm -f "Step6_4_"$type1"_DMGs_vs_"$blast_db"_genome_tmp.blast"
done

#create final output - BADGE_final.tsv

echo "DMG_ID	percent_occurrence	dc_blast_hit	max_blastn_hit_length	ORF_ID	ORF_length	annotation	contig	start	stop" > ".BADGE_"$type1"_final_out.tsv"
x=1
while read IDs	
	do
	y=1
	
	#get sequences of DMGs

	if $protein_level
		then	
		for ID in $IDs
			do
			$blastbin_path/blastdbcmd -db $type1"_orfs_aa" -entry $ID | sed "s/lcl|//" >> "Step6_4_DMG_"$x"_seq_align_aa.fasta"
			$blastbin_path/blastdbcmd -db $type1"_orfs" -entry $ID | sed "s/lcl|//" >> "Step6_4_DMG_"$x"_seq_align.fasta"
		done
	else
		for ID in $IDs
			do
			$blastbin_path/blastdbcmd -db $type1"_orfs" -entry $ID | sed "s/lcl|//" >> "Step6_4_DMG_"$x"_seq_align.fasta"
		done	
	fi

	# get DMG positions in genome

	grepstring=`echo $IDs | sed s/\ /\|/g`
	grep -iwE $grepstring "Step6_4_"$type1"_DMGs_genome.blast" | awk '{print $2 "\t" $3 "\t" $4}' | awk '!x[$0]++' > "Step6_4_DMG_"$x"_pos_tmp.identifier"
	grep -iwE $grepstring "Step6_4_"$type1"_DMGs_genome.blast" |  awk '{print $1}' | uniq  > "Step6_4_DMG_"$x"_ID_tmp.identifier"
	DMG_rep=`echo $IDs | awk '{print $1}'`
	
	# compare number of DMG identifiers with number of possitions in genome (in case of missing annotations)
	num_positions=`cat "Step6_4_DMG_"$x"_pos_tmp.identifier" | wc -l`
	num_IDs=`cat "Step6_4_DMG_"$x"_ID_tmp.identifier" | wc -l`

	if [[ ! $num_positions -eq $num_IDs ]]
		then

 		# then get DMG positions step by step		
		for ID in $IDs
			do 
		
			grep -iwE $ID "Step6_4_"$type1"_DMGs_genome.blast" | awk '{print $2 "\t" $3 "\t" $4}' | awk '!x[$0]++' > "Step6_4_DMG_"$x"_"$ID"_pos_tmp.identifier"
			
			# use md5sum to identify equal position files as only one is needed
			md5checksum=`md5sum  "Step6_4_DMG_"$x"_"$ID"_pos_tmp.identifier" | awk '{print $1}'`

			echo -e $ID"\t"$md5checksum"\tStep6_4_DMG_"$x"_"$ID"_pos_tmp.identifier" >> "Step6_4_DMG_"$x"_pos_md5.identifier"

		done

		sort "Step6_4_DMG_"$x"_pos_md5.identifier" | sort -k2,2 > "Step6_4_DMG_"$x"_pos_md5_sort.identifier"
		awk '{print $2}' "Step6_4_DMG_"$x"_pos_md5_sort.identifier" | uniq -c | sort -k1,1nr > "Step6_4_DMG_"$x"_pos_md5_sort_count.identifier"

		extra_DMG_setNum=1
		while read line
			do

			num_IDs=`echo $line | awk '{print $1}'` 
			file_md5=`echo $line | awk '{print $2}'`
			file_md5_name=`grep $file_md5 "Step6_4_DMG_"$x"_pos_md5_sort.identifier" | head -1 | awk '{print $3}'`

	
			grep $file_md5 "Step6_4_DMG_"$x"_pos_md5_sort.identifier" >  "Step6_4_DMG_"$x"_pos_md5_sort_ID_tmp.identifier"

		 
			lineNum=1
			extra_DMG_Num=1
			while read line
				do

				ID_name=`awk  -vlineNum=$lineNum 'NR == lineNum {print $1; exit}' "Step6_4_DMG_"$x"_pos_md5_sort_ID_tmp.identifier"`

				if [[ -z $ID_name ]]
					then

					ID_name="non_annotated_DMG_"$extra_DMG_Num"_"$extra_DMG_setNum
					extra_DMG_Num=$(( extra_DMG_Num+1 ))

					fi

				ID_position=`echo $line | sed 's/ /\t/g'`
				echo -e $ID_name"\t""$ID_position" >> "Step6_4_DMG_"$x"_ID_pos.identifier"

				lineNum=$(( lineNum+1 ))

			done < $file_md5_name
		extra_DMG_setNum=$(( extra_DMG_setNum+1 ))
		done < "Step6_4_DMG_"$x"_pos_md5_sort_count.identifier"
		cat "Step6_4_DMG_"$x"_ID_pos.identifier" |  awk '{print $1}'  > "Step6_4_DMG_"$x"_ID_tmp.identifier"

		#clean up tmp files
		
		rm -f "Step6_4_DMG_"$x"_"$ID"_pos_tmp.identifier" "Step6_4_DMG_"$x"_pos_md5.identifier" "Step6_4_DMG_"$x"_pos_md5_sort_count.identifier" "Step6_4_DMG_"$x"_pos_md5_sort_ID_tmp.identifier"

	else
		

		pr -m -t -s "Step6_4_DMG_"$x"_ID_tmp.identifier" "Step6_4_DMG_"$x"_pos_tmp.identifier" > "Step6_4_DMG_"$x"_ID_pos.identifier" 
		

	fi

	echo | cat - "Step6_4_DMG_"$x"_ID_tmp.identifier" > "Step6_4_DMG_"$x"_ID.identifier"
	rm -f "Step6_4_DMG_"$x"_ID_tmp.identifier" "Step6_4_DMG_"$x"_pos_tmp.identifier"

 	#process single DMGs

	while read ID
		do 
		if (($y == 1)) #DMG rep 
			then
			DMG_name="DMG_"$x

			#percent_occurrence

			perc_occurrence=`grep -w $DMG_rep "Step6_1_"$type1"_DMGs.distribution" | awk '{
				occurrence=$2;
				for(i=3; i<=NF; i++) {
				occurrence=occurrence+$i
					};
				perc_occurrence=occurrence/(NF-1)*100;
				print perc_occurrence
			}'` 

			#check for blast_dc hit of current DMG in genome

			if grep -qw $DMG_rep "Step6_2_"$type1"_DMGs_dc.blast"
			then
			dc_megablast_hit="yes"
			else
			dc_megablast_hit="no"
			fi

			#check for blastn hit of current DMG in genome

			if grep -qw $DMG_rep "Step6_2_"$type1"_DMGs_blastn.blast"
			then
			blastn_hit_length=`grep -w $DMG_rep "Step6_2_"$type1"_DMGs_blastn.blast" | awk '{ print $2}'| sort -nur | awk ' NR==1 { print $1}'`
			blastn_hit="yes"
			else
			blastn_hit="no"
			fi

			#get DMG position of current DMG in genome

			if grep -qw $DMG_rep "Step6_4_DMG_"$x"_ID_pos.identifier"
			then
			contig_start_stop=`grep -w $DMG_rep "Step6_4_DMG_"$x"_ID_pos.identifier" | awk '{print $2 "\t" $3 "\t" $4}'`
			else
			contig_start_stop="gene position	not	found"
			fi

			ORF_L_A=`$blastbin_path/blastdbcmd -db $type1"_orfs" -entry $DMG_rep -outfmt "%l	%t"`

			#print global/first specific DMG info to file

			echo "$DMG_name	$perc_occurrence	$dc_megablast_hit	$blastn_hit_length	$DMG_rep	$ORF_L_A	$contig_start_stop" >> ".BADGE_"$type1"_final_out.tsv"
			elif [[ "$ID" != "$DMG_rep" ]]
			then
			#get DMG position of current DMG in genome

			if grep -qw $ID "Step6_4_DMG_"$x"_ID_pos.identifier"
			then
			contig_start_stop=`grep -w $ID "Step6_4_DMG_"$x"_ID_pos.identifier" | awk '{print $2 "\t" $3 "\t" $4}'`
			else
			contig_start_stop="gene position	not	found"
			fi
			
			#get ID info from blastdb
			if [[ "$ID" == "non_annotated_DMG"* ]]
				then
			#print orf specific info to file
			echo "				$ID			$contig_start_stop" >> ".BADGE_"$type1"_final_out.tsv"
			else
			ORF_L_A=`$blastbin_path/blastdbcmd -db $type1"_orfs" -entry $ID -outfmt "%l	%t"`	
			#print orf specific info to file
			echo "				$ID	$ORF_L_A	$contig_start_stop" >> ".BADGE_"$type1"_final_out.tsv"
			fi

	
			
		fi
	y=$(( y+1 ))

	done < "Step6_4_DMG_"$x"_ID.identifier"
x=$(( x+1 ))
done < "Step6_1_"$type1"_DMGs_vs_"$type1"_orfs_sort.identifier"

#clean up tmp files

rm -f "Step6_4_DMG_"*"_ID.identifier"

if $protein_level
	then
	cp "Step6_1_"$type1"_DMGs.fasta" ".BADGE_"$type1"_DMGs.fasta"
	cp "Step6_1_"$type1"_DMGs_aa.fasta" ".BADGE_"$type1"_DMGs_aa.fasta"
else
	cp "Step6_1_"$type1"_DMGs.fasta" ".BADGE_"$type1"_DMGs.fasta"
fi

##############################################################################################################################################################

#add DMG ID to final fasta files

#create new IDs
x=1
while read old_line
	do
		#if line contains ID (header)
    		if [[ "$old_line" == ">"* ]]
			then
			DMG_name="DMG_"$x
			x=$(( x+1 ))
			old_ID=`echo $old_line | cut -d ">" -f 2 | sed "s/lcl|//"`
			echo -e ">"$DMG_name" "$old_ID >> "BADGE_"$type1"_vs_"$type2"_DMGs_new.annotation"
		fi
done < ".BADGE_"$type1"_DMGs.fasta"



IFS=$'\n' read -d '' -r -a new_ID < "BADGE_"$type1"_vs_"$type2"_DMGs_new.annotation"
n=0

#replace old IDs (header) with new IDs

while read old_line
	do
    		if [[ "$old_line" == ">"* ]]
			then
        		echo ${new_ID[n]} >> "BADGE_"$type1"_vs_"$type2"_DMGs_tmp.fasta"
        		((n=n+1))
    		else
			echo $old_line >> "BADGE_"$type1"_vs_"$type2"_DMGs_tmp.fasta"
		fi
done < ".BADGE_"$type1"_DMGs.fasta"

mv -f "BADGE_"$type1"_vs_"$type2"_DMGs_tmp.fasta" ".BADGE_"$type1"_DMGs.fasta"



#replace old IDs with new IDs for amino acid sequences (if PROTEIN-LEVEL switched on)

if $protein_level
	then
	
	#create array with new IDs for amino acid sequences

	IFS=$'\n' read -d '' -r -a new_ID < "BADGE_"$type1"_vs_"$type2"_DMGs_new.annotation"
	n=0
		while read old_line
			do
    			if [[ "$old_line" == ">"* ]]
				then
        			echo ${new_ID[n]} >> "BADGE_"$type1"_DMGs_aa_tmp.fasta"
        			((n=n+1))
    			else
				echo $old_line >> "BADGE_"$type1"_DMGs_aa_tmp.fasta"
			fi
		done < ".BADGE_"$type1"_DMGs_aa.fasta"
	mv -f "BADGE_"$type1"_DMGs_aa_tmp.fasta" ".BADGE_"$type1"_DMGs_aa.fasta"	
fi

#clean up temporary files of ID replacement

rm -f "BADGE_"$type1"_vs_"$type2"_DMGs_new.annotation"


#control alignments

if $protein_level || $mut_level_aa
	then
	$blastbin_path/blastp -db $type2"_orfs_aa" -query ".BADGE_"$type1"_DMGs_aa.fasta"  -num_alignments 1 -html > ".BADGE_"$type1"_blastp.alignment"
fi

$blastbin_path/blastn -db $type2"_genomes" -query ".BADGE_"$type1"_DMGs.fasta" -task dc-megablast -num_alignments 1 -num_threads 4 -html > ".BADGE_"$type1"_dc_megablast.alignment"
$blastbin_path/blastn -db $type2"_genomes" -query ".BADGE_"$type1"_DMGs.fasta" -task blastn -num_alignments 1 -num_threads 4 -html > ".BADGE_"$type1"_blastn.alignment"

#clean up

mkdir ./blast_dbs 
mv ./*.n* ./*.log ./blast_dbs
mv ./$type1*.* ./$type2*.* ./blast_dbs
if $protein_level && [ `ls -1 ./*_aa.p* 2>/dev/null | wc -l ` -gt 0 ]
		then
		mv ./*_aa.p* ./blast_dbs
fi

for (( x=1; x<=$numsteps ; x++ ))
	do
	if (( $x < 4 ))
		then
		mkdir ./Step_$x
		mv ./Step$x*.* ./Step_$x

	elif (( $x == 4 )) && $dc_filter
		then
		mkdir ./Step_$x
		mv ./Step$x*.* ./Step_$x

	elif (( $x == 5 )) && $blastn_filter
		then
		mkdir ./Step_$x
		mv ./Step$x*.* ./Step_$x
	
	elif (( $x == 6 ))
		then
		mkdir ./Step_$x
		mv ./Step$x*.* ./Step_$x
	fi
done

mkdir BADGE_DMGs_fasta_for_alignments

if [ `ls -1 ./Step_6/Step6_4*seq_align*.fasta 2>/dev/null | wc -l ` -gt 0 ]
	then
	mv ./Step_6/Step6_4*seq_align*.fasta ./BADGE_DMGs_fasta_for_alignments/
fi

if $clean_up
	then
		rm -rf ./Step_* ./blast_dbs
	else
	echo		
	echo -e "All files moved to corresponding directory"
	echo	
fi

if $protein_level && $protein_level_clean_up
	then
	rm -fr ../orfs_aa
fi

mv -f ".BADGE_"$type1"_final_out.tsv" "BADGE_"$type1"_vs_"$type2"_final_out.tsv"
mv -f ".BADGE_"$type1"_DMGs.fasta" "BADGE_"$type1"_vs_"$type2"_DMGs.fasta"
mv -f ".BADGE_"$type1"_dc_megablast.alignment" "BADGE_"$type1"_vs_"$type2"_dc_megablast.alignment"
mv -f ".BADGE_"$type1"_blastn.alignment" "BADGE_"$type1"_vs_"$type2"_blastn.alignment"
mv -f ".BADGE_"$type1"_DMGs.frequency" "BADGE_"$type1"_vs_"$type2"_DMGs.frequency"
mv -f ".BADGE_"$type1"_DMGs.distribution" "BADGE_"$type1"_vs_"$type2"_DMGs.distribution"
mv -f ".BADGE.settings" "BADGE.settings"

if $protein_level
	then 
	mv -f ".BADGE_"$type1"_DMGs_aa.fasta" "BADGE_"$type1"_vs_"$type2"_DMGs_aa.fasta"
	mv -f ".BADGE_"$type1"_blastp.alignment" "BADGE_"$type1"_vs_"$type2"_blastp.alignment"
fi



#all DMGs versus all DMGs

if $identify_overlapping
	then

	if $protein_level
			then
		cat "BADGE_"$type1"_vs_"$type2"_DMGs.fasta" > split_input.fasta
		seq_num=`grep -c ">" split_input.fasta`
		if [[ $num_blast_proc -gt $seq_num ]]
			then
			num_blast_proc=1
			else
			num_blast_proc=$set_num_blast_proc
		fi
		split_at_num=$(( seq_num/num_blast_proc ))
		awk -v split_at_num=$split_at_num -v fastafilebasename="seq_split" 'BEGIN {n_seq=0;} /^>/ {if(n_seq%split_at_num==0){fastafile=sprintf(fastafilebasename"%d.fasta",n_seq);} print >> fastafile; n_seq++; next;} { print >> fastafile; }' < split_input.fasta
	
		#perform blast
	
		$blastbin_path/makeblastdb -in "BADGE_"$type1"_vs_"$type2"_DMGs.fasta" -input_type fasta -dbtype prot -title DMGs -parse_seqids -out DMGs -logfile DMGs_genome_db.log
	
		query_num=1
		for queryfiles in ./seq_split*".fasta"
			do
			$blastbin_path/blastp -db DMGs -query $queryfiles -outfmt "6 qseqid sseqid qlen slen pident length evalue" -max_target_seqs 100 -num_threads 4 | awk -v blastp_between_group_qscov=$blastp_between_group_qscov -v blastp_within_group_qscov=$blastp_within_group_qscov -v blastp_perc_identity_cut=$blastp_perc_identity_cut -v blastp_e_value=$blastp_e_value '{if ($6/$3 >= (blastp_between_group_qscov + blastp_within_group_qscov)/2 && $6/$4 >= (blastp_between_group_qscov + blastp_within_group_qscov)/2 && $5 >= blastp_perc_identity_cut && $7 <= blastp_e_value) print $0}' > "seq_split_"$query_num".blast" &
			query_num=$(( query_num+1 ))	
		done
		wait
		cat "seq_split_"*".blast" > DMGs.blast
	
		#clean up split files
	
		rm -f "seq_split_"*".blast"  "seq_split"*".fasta" split_input.fasta
	
		DMGs_qscov=`awk -v blastp_between_group_qscov=$blastp_between_group_qscov -v blastp_within_group_qscov=$blastp_within_group_qscov 'BEGIN {print ((blastp_between_group_qscov + blastp_within_group_qscov)/2)*100}'`
	
	else	
	
		cat "BADGE_"$type1"_vs_"$type2"_DMGs.fasta" > split_input.fasta
		seq_num=`grep -c ">" split_input.fasta`
		if [[ $num_blast_proc -gt $seq_num ]]
			then
			num_blast_proc=1
			else
			num_blast_proc=$set_num_blast_proc
		fi
		split_at_num=$(( seq_num/num_blast_proc ))
		awk -v split_at_num=$split_at_num -v fastafilebasename="seq_split" 'BEGIN {n_seq=0;} /^>/ {if(n_seq%split_at_num==0){fastafile=sprintf(fastafilebasename"%d.fasta",n_seq);} print >> fastafile; n_seq++; next;} { print >> fastafile; }' < split_input.fasta
	
		#perform blast
	
		$blastbin_path/makeblastdb -in "BADGE_"$type1"_vs_"$type2"_DMGs.fasta" -input_type fasta -dbtype nucl -title DMGs -parse_seqids -out DMGs -logfile DMGs_genome_db.log
	
		query_num=1
		for queryfiles in ./seq_split*".fasta"
			do
			$blastbin_path/blastn -db DMGs -query $queryfiles -outfmt "6 qseqid sseqid qlen slen pident length evalue" -max_target_seqs 100 -num_threads 4 -task dc-megablast | awk -v megablast_between_group_qscov=$megablast_between_group_qscov -v megablast_within_group_qscov=$megablast_within_group_qscov -v megablast_perc_identity_cut=$megablast_perc_identity_cut -v megablast_e_value=$megablast_e_value '{if ($6/$3 >= (megablast_between_group_qscov + megablast_within_group_qscov)/2 && $6/$4 >= (megablast_between_group_qscov + megablast_within_group_qscov)/2 && $5 >= megablast_perc_identity_cut && $7 <= megablast_e_value) print $0}' > "seq_split_"$query_num".blast" &
			query_num=$(( query_num+1 ))	
		done
		wait
		cat "seq_split_"*".blast" > DMGs.blast
	
		#clean up split files
	
		rm -f "seq_split_"*".blast"  "seq_split"*".fasta" split_input.fasta
	
		DMGs_qscov=`awk -v megablast_between_group_qscov=$megablast_between_group_qscov -v megablast_within_group_qscov=$megablast_within_group_qscov 'BEGIN {print ((megablast_between_group_qscov + megablast_within_group_qscov)/2)*100}'`
	fi

	cat DMGs.blast | awk '{if ($1 != $2) print $1 " " $2}' | awk '{
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
		END{print prev " " outstring;}' > overlapping_DMGs.identifier
	
	file_size=`cat overlapping_DMGs.identifier | wc -c`

	if [[ $file_size -gt 2 ]]
		then
	
		line2replace="DMG_ID	percent_occurrence	dc_blast_hit	max_blastn_hit_length	ORF_ID	ORF_length	annotation	contig	start	stop"
		new_line="DMG_ID	percent_occurrence	dc_blast_hit	max_blastn_hit_length	ORF_ID	ORF_length	annotation	contig	start	stop	overlapping DMGs (pident > $DMGs_qscov)"	
		sed -i "s/$line2replace/$new_line/g" "BADGE_"$type1"_vs_"$type2"_final_out.tsv"
		while read line
		do
		search_string=`echo $line | awk '{print $1}'`
		overlapping_DMGs_identifiers=`echo $line | awk -F " " '{for (i=2; i<NF; i++) printf $i ", "; print $NF}'`
		line2replace=`grep -w "^$search_string" "BADGE_"$type1"_vs_"$type2"_final_out.tsv"`
		new_line="$line2replace	$overlapping_DMGs_identifiers"
		sed -i "s/$line2replace/$new_line/g" "BADGE_"$type1"_vs_"$type2"_final_out.tsv"
		done < overlapping_DMGs.identifier
	fi

	#cleanup

	rm -f DMGs* overlapping_DMGs.identifier

fi

#prepare for next comparison

cd $BADGE_path

#set min_DMG_occurrence back to initially chosen value

min_DMG_occurrence=$set_min_DMG_occurrence

num_blast_proc=$set_num_blast_proc

} 


#end BADGE_function function


#start of function - time

stime=$(date +"%s");

#execute BADGE_function

if true
	then

	#get types genomes dir and make list

	type_list=""
	for i in $(ls -d ./genomes/*)
		do
		types=`basename "$i"`
		type_list=$type_list" "$types
	done

	#create all possible pair combinations

	set -- ${type_list}
	for a_type
		do
    		shift
    		for b_type
			do
			BADGE_function $a_type $b_type
			BADGE_function $b_type $a_type
   		done
	done

	#end of function -time

	etime=$(date +"%s"); 

	#calculate the elapsed time and print it to settings-files

	elapsed_time=$(($etime-$stime))

	echo "Elapsed processor time:" $(($elapsed_time / 60))"min and" $(($elapsed_time % 60))"sec"
	echo
	echo >> ./$comp_tag/BADGE.settings
	echo		"Elapsed processor time:" $(($elapsed_time / 60))"min and" $(($elapsed_time % 60))"sec"  >> ./$comp_tag/BADGE.settings
fi

cd
