#CHECK arguments passed and do what user wants to do:
# - files for first part (merging all ligands and creating folders)
# - rdock for all rdock calculations including grid generation
# - glide for glide steps,
# - glidefix for fixed glide grid generation to avoid nodes SCHRODINGER errors
### BY DEFAULT, no arguments passed, it will do files, rdock and glide
if [ $# -eq 0 ];
then
        #default parameters
        rdock=true
        glide=true
        glidefix=false
else
        #if there are some arguments, all the parameters will be false but the ones the user adds
        rdock=false
        glide=false
        glidefix=false

        #now check which one of them user wants to do
        for  a in $*
        do
                if [ $a == rdock ];
                then
                        rdock=true
                elif [ $a == glide ];
                then
                        glide=true
                elif [ $a == glidefix ];
                then
                        glidefix=true
                else
                        echo UNKNOWN OPTIONS, please use rdock, glide or glidefix!
                        exit 1;
                fi;
        done;
fi;

echo rdock $rdock glide $glide glidefix $glidefix;

dudsys=$(perl -e '@F=split(/\//,$ENV{PWD});print "$F[5]\n"')


##GLIDE DOCKING##########################################
	if $glide; then
		##files needed for glide docking 
		##Parameters:
		# grid found in DUD folder in marc
		# ligands also in DUD folder
		# name stantardized for 'DUD'_glide_out.maegz
		# 100 poses, NO cutoff of -4, and (nligans*nposes) best reported
		
		#nligands is the number of ligands in the input file and nrep is the maximum of poses to write in the output
		nligands=`grep -c '$$$$' $dudsys\_all_ligands.sd`
		nrep=`echo $nligands*5000 | bc`
		
		#creates glide.in file to run docking
		python $SCRIPTS/createGlideIn.py -g /marc/data/sruiz/DUD/$dudsys/glide/$dudsys\_grid.zip -l /marc/data/sruiz/DUD/$dudsys/$dudsys\_all_ligands.sd -f $dudsys\_glide.in -e -p 5000 -n $nrep
		
		#creates q input file to submit in marc (5 cpus)
		python $SCRIPTS/createQin_glide.py -t $SCRIPTS/files/glide_template.q -c 5 -i $dudsys\_glide.in -n $dudsys\_glide.q
	
		#moves both files to glide folder
		mv $dudsys\_glide.in $dudsys\_glide.q glide
	fi;
	#if glidefix flag is on.. make the corresponding inputs
	if $glidefix; then
		python $SCRIPTS/createQin_glide.py -t $SCRIPTS/files/glide_template_fixed.q -c 5 -i $dudsys\_glide.in -n $dudsys\_glide.q
		mv $dudsys\_glide.q glide
	fi;
	
	#sort of instructions to the user
	echo "Files for running glide in marc named $dudsys\_glide.in $dudsys\_glide.q (using 5CPUS), to run in marc:"
		echo -e "\tscptomarc \"glide/$dudsys\_glide.in glide/$dudsys\_glide.q\" /data/sruiz/DUD/$dudsys/glide/\n\tmarc \"cd /data/sruiz/DUD/$dudsys/glide/; queue -a $dudsys\_glide.q -c 5\"\n"

	
##RDOCK###################################################
	if $rdock; then
		#makes folders for the results and the splitted ligands (if more than 200)
		mkdir rdock/results
		mkdir rdock/results/logs
		mkdir rdock/split_ligands
		#first of all, if the ligands are in a sdfile with more than 200 ligands, split it into different files
		#otherwise, just make a copy of this sd file to the folder, for making easy following steps
		if [ $(grep -c '$$$$' $dudsys\_all_ligands.sd) -gt 200 ]
		then 
			sdsplit -200 -ordock/split_ligands/$dudsys\_split $dudsys\_all_ligands.sd > runDock_$dudsys.log
			echo The ligands have been splitted into 200 molecules sd files, they can be found in rdock/split_ligands 
		else
			cp $dudsys\_all_ligands.sd rdock/split_ligands
		fi
	
		#foreach file in rdock split_ligands.. run createQin and save it in rdock folder.
		cp $SCRIPTS/files/rdock_filter.txt rdock #copy filter txt to running folder
		cd rdock/split_ligands/
		#parameters:
		#template.q in files, pathway to 
		for file in *; 
			do
			python $SCRIPTS/rdock/createQin.py -t $SCRIPTS/files/rdock_tmp_DUD.q -p $file -i $dudsys\_rdock.prm -r 100 -a $dudsys\_rdock.as -m $dudsys\_rdock.mol2 -l xtal-lig.sd -s dock.prm -n $file;
			done
		mv *.q ../
		cd ../../
	
		cp $SCRIPTS/addtoQ.csh rdock
	
		echo Files for rdock can be found in its folder.
		echo To run it in marc:
		echo -e "\tscptomarc rdock /data/sruiz/DUD/$dudsys\n\tmarc \"cd /data/sruiz/DUD/$dudsys/rdock; ./addtoQ.csh\"\n"
	fi;
		##next step is copying to marc and running both glide and rdock in there

