#! /usr/bin/env python
#
# Calculate SMART RMSD with or without molecular superposition (FIT or NOFIT) 
# Script distributed under GNU LGPL 3.0 along rDock software.
# 
# Author: Daniel Alvarez-Garcia
# Date: 08-11-2013

import math
import pybel
import numpy as npy

def superpose3D(ref, target, weights=None,refmask=None,targetmask=None,returnRotMat=False):
    """superpose3D performs 3d superposition using a weighted Kabsch algorithm : http://dx.doi.org/10.1107%2FS0567739476001873 & doi: 10.1529/biophysj.105.066654
    definition : superpose3D(ref, target, weights,refmask,targetmask)
    @parameter 1 :  ref - xyz coordinates of the reference structure (the ligand for instance)
    @type 1 :       float64 numpy array (nx3)
    ---
    @parameter 2 :  target - theoretical target positions to which we should move (does not need to be physically relevant.
    @type 2 :       float 64 numpy array (nx3)
    ---
    @parameter 3:   weights - numpy array of atom weights (usuallly between 0 and 1)
    @type 3 :       float 64 numpy array (n)
    @parameter 4:   mask - a numpy boolean mask for designating atoms to include
    Note ref and target positions must have the same dimensions -> n*3 numpy arrays where n is the number of points (or atoms)
    Returns a set of new coordinates, aligned to the target state as well as the rmsd
    """
    if weights == None :
        weights=1.0
    if refmask == None :
        refmask=npy.ones(len(ref),"bool")
    if targetmask == None :
        targetmask=npy.ones(len(target),"bool")
    #first get the centroid of both states
    ref_centroid = npy.mean(ref[refmask]*weights,axis=0)
    #print ref_centroid
    refCenteredCoords=ref-ref_centroid
    #print refCenteredCoords
    target_centroid=npy.mean(target[targetmask]*weights,axis=0)
    targetCenteredCoords=target-target_centroid
    #print targetCenteredCoords
    #the following steps come from : http://www.pymolwiki.org/index.php/OptAlign#The_Code and http://en.wikipedia.org/wiki/Kabsch_algorithm
    # Initial residual, see Kabsch.
    E0 = npy.sum( npy.sum(refCenteredCoords[refmask] * refCenteredCoords[refmask]*weights,axis=0),axis=0) + npy.sum( npy.sum(targetCenteredCoords[targetmask] * targetCenteredCoords[targetmask]*weights,axis=0),axis=0)
    reftmp=npy.copy(refCenteredCoords[refmask])
    targettmp=npy.copy(targetCenteredCoords[targetmask])
    #print refCenteredCoords[refmask]
    #single value decomposition of the dotProduct of both position vectors
    try:
        dotProd = npy.dot( npy.transpose(reftmp), targettmp* weights)
        V, S, Wt = npy.linalg.svd(dotProd )
    except Exception:
        try:
            dotProd = npy.dot( npy.transpose(reftmp), targettmp)
            V, S, Wt = npy.linalg.svd(dotProd )
        except Exception:
            print >> sys.stderr,"Couldn't perform the Single Value Decomposition, skipping alignment"
        return ref, 0
    # we already have our solution, in the results from SVD.
    # we just need to check for reflections and then produce
    # the rotation.  V and Wt are orthonormal, so their det's
    # are +/-1.
    reflect = float(str(float(npy.linalg.det(V) * npy.linalg.det(Wt))))
    if reflect == -1.0:
        S[-1] = -S[-1]
        V[:,-1] = -V[:,-1]
    rmsd = E0 - (2.0 * sum(S))
    rmsd = npy.sqrt(abs(rmsd / len(ref[refmask])))   #get the rmsd
    #U is simply V*Wt
    U = npy.dot(V, Wt)  #get the rotation matrix
    # rotate and translate the molecule
    new_coords = npy.dot((refCenteredCoords), U)+ target_centroid  #translate & rotate
    #new_coords=(refCenteredCoords + target_centroid)
    #print U
    if returnRotMat : 
        return new_coords,rmsd, U
    return new_coords,rmsd


def squared_distance(coordsA, coordsB):
    """Find the squared distance between two 3-tuples"""
    sqrdist = sum( (a-b)**2 for a, b in zip(coordsA, coordsB) )
    return sqrdist
    
def rmsd(allcoordsA, allcoordsB):
    """Find the RMSD between two lists of 3-tuples"""
    deviation = sum(squared_distance(atomA, atomB) for
                    (atomA, atomB) in zip(allcoordsA, allcoordsB))
    return math.sqrt(deviation / float(len(allcoordsA)))
    
def mapToCrystal(xtal, pose):
    """Some docking programs might alter the order of the atoms in the output (like Autodock Vina does...)
     this will mess up the rmsd calculation with OpenBabel"""
    query = pybel.ob.CompileMoleculeQuery(xtal.OBMol) 
    mapper=pybel.ob.OBIsomorphismMapper.GetInstance(query)
    mappingpose = pybel.ob.vvpairUIntUInt()
    exit=mapper.MapUnique(pose.OBMol,mappingpose)
    return mappingpose[0]

    
if __name__ == "__main__":
    import sys
    
    if len(sys.argv) < 3:
	sys.exit("USAGE: smartRMSD.py reference.sd poses.sd [fit]")
	
    xtal = sys.argv[1]
    poses = sys.argv[2]

    fit = False
    try:
	fit=sys.argv[3]
	if fit == 'fit': fit=True
    except:
	fit = False

    # Read crystal pose
    crystal = next(pybel.readfile("sdf", xtal))
    crystal.removeh()

    # Find automorphisms involving only non-H atoms
    mappings = pybel.ob.vvpairUIntUInt()
    bitvec = pybel.ob.OBBitVec()
    lookup = []
    for i, atom in enumerate(crystal):
        lookup.append(i)
    success = pybel.ob.FindAutomorphisms(crystal.OBMol, mappings)

    # Find the RMSD between the crystal pose and each docked pose
    xtalcoords = [atom.coords for atom in crystal]
    dockedposes = pybel.readfile("sdf", poses)
    if fit: print "POSE\tRMSD_FIT"
    else: print "POSE\tRMSD_NOFIT"
    for i, dockedpose in enumerate(dockedposes):
        dockedpose.removeh()
        mappose = mapToCrystal(crystal, dockedpose)
        mappose = npy.array(mappose)
        mappose = mappose[npy.argsort(mappose[:,0])][:,1]
        posecoords = npy.array([atom.coords for atom in dockedpose])[mappose]
        resultrmsd = 999999999999
        for mapping in mappings:
            automorph_coords = [None] * len(xtalcoords)
            for x, y in mapping:
                automorph_coords[lookup.index(x)] = xtalcoords[lookup.index(y)]
            mapping_rmsd = rmsd(posecoords, automorph_coords)
            if mapping_rmsd < resultrmsd:
                resultrmsd = mapping_rmsd
            if fit: 
		fitted_pose, fitted_rmsd = superpose3D(npy.array(automorph_coords), npy.array(posecoords))
            	if fitted_rmsd < resultrmsd:
                	resultrmsd = fitted_rmsd
	
	print "%d\t%.2f"%((i+1),resultrmsd)