for f in inputs/asinex_forligprep0*; do n=$(basename $f .smi | sed 's/asinex_forligprep//'); sed 's/99/'$n'/' qsub_ligprep99.sh | sed 's/_PROV_/asinex/' | sed 's/LC/AS/' | sed 's/asinex\//asinex\/ligprep\//'> qsub_ligprep$n.sh; done
