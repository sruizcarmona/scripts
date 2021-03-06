##RDOCK###################################################
#create new folder for rdock docking
#add as a parameter the name of the folder and second, the input of ligands!

if [ $# -lt 2 ];
then 
	echo There are some parameters missing
	echo To call the script please write:
	echo rDock_EXTRA.sh JOB_FOLDER_NAME LIGS_SOURCE
	exit
fi

folder=$1
dudsys=$(perl -e '@F=split(/\//,$ENV{PWD});print "$F[5]\n"')
ligands_src=$2

echo Working on DUD $dudsys, job $folder and ligands $ligands_src

	#makes folders for the results and the splitted ligands (if more than 200)
	mkdir $folder
	mkdir $folder/results
	mkdir $folder/results/logs
	mkdir $folder/split_ligands
	#first of all, if the ligands are in a sdfile with more than 200 ligands, split it into different files
	#otherwise, just make a copy of this sd file to the folder, for making easy following steps
	if [ $(grep -c '$$$$' $ligands_src) -gt 200 ]
		then 
			sdsplit -100 -o$folder/split_ligands/$dudsys\_split $ligands_src > runDock_$dudsys.log
			echo The ligands from $ligands_src have been splitted into 100 molecules sd files, they can be found in $folder/split_ligands 
		else
			cp $ligands_src $folder/split_ligands
	fi;
	#foreach file in rdock split_ligands.. run createQin and save it in rdock folder.
	cp $SCRIPTS/files/rdock_filter.txt $folder #copy filter txt to running folder
	cp rdock/*_rdock.* rdock/xtal-lig.sd $folder
	
	cd $folder/split_ligands/
	#parameters:
	#template.q in files, pathway to 
	for file in *; 
		do
		python $SCRIPTS/rdock/createQin.py -t $SCRIPTS/files/rdock_tmp_DUD.q -p $file -i $dudsys\_rdock.prm -r 100 -a $dudsys\_rdock.as -m $dudsys\_rdock.mol2 -l xtal-lig.sd -s dock.prm -n $file;
		done
	mv *.q ../
	cd ../../

	cp $SCRIPTS/addtoQ.csh $folder

	echo Files for rdock and $folder can be found in its folder.
	echo To run it in marc:
	echo -e "\tscptomarc $folder /data/sruiz/DUD/$dudsys\n\tmarc \"cd /data/sruiz/DUD/$dudsys/$folder; ./addtoQ.csh\"\n"
	##next step is copying to marc and running both glide and rdock in there

