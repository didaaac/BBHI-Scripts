#Working script for corregistration from fMRI to T1. Includes motion realign + Field Map correction + intermodal corregistration. 

#Input fMRI data
FMRI_FOLDER=/mnt/nas01/lifebrain/BBHI/pilots/didac/RESTING
FUNC='20180420_105406restingaps007a001.nii' #single band image
REF_FUNC='20180420_105406restingaps006a001.nii'  #multiband 4D image
SE_GFM_AP='20180420_105406SPECHOGFMAPs004a001.nii'
SE_GFM_PA='20180420_105406SPECHOGFMPAs005a001.nii'

#Input T1 image
T1_FILE='/mnt/nas01/lifebrain/BBHI/pilots/didac/T1/20180420_105406T1wMPRs003a1001.nii'

#output folder
OUTPUT_FOLDER=/psiquiatria/home/lifebrain/BBHI/QA/didac/resting

#output nameing convention(not necessary to modify)
SE_GFM='se_gfm_ap_pa'
FMRI_ORIG='fmri'

#Constants
EPI_FACTOR=104 #Factor de epi (NOTA: és la mateixa en el SE GFM que en la multiband EPI fmri)
ECHO_SPACING=0.58 #Esp. entre ecos
DWELL_TIME=0.05974 #ECHO_SPACING*(EPI_FACTOR-1)/1000=0.102


#Remove first TRs 
echo "removing 10 first TRs and copying data to output folder"
fslroi $FMRI_FOLDER/${FUNC}.nii.gz $OUTPUT_FOLDER/$FMRI_ORIG.nii.gz 10 -1 

#Merges SE field maps and estimates GFM unwarp with topup
echo "Merges SE field maps and estimates GFM unwarp with topup"
fslmerge -t $OUTPUT_FOLDER/${SE_GFM} $FMRI_FOLDER/${SE_GFM_AP} $FMRI_FOLDER/${SE_GFM_PA}
printf "0 -1 0 0.0959\n0 -1 0 0.0959\n0 -1 0 0.0959\n0 1 0 0.05974\n0 1 0 0.05974\n0 1 0 0.05974 " > ${OUTPUT_FOLDER}/acqparams.txt
topup --imain=$OUTPUT_FOLDER/${SE_GFM} --datain=${OUTPUT_FOLDER}/acqparams.txt --config=b02b0.cnf --out=${OUTPUT_FOLDER}/topup_results --fout=${OUTPUT_FOLDER}/f_topup_results --iout=${OUTPUT_FOLDER}/topup_unwarped

#Multiplies field map by 2*pi to have frequency in rads
fslmaths ${OUTPUT_FOLDER}/f_topup_results -mul 6.28 ${OUTPUT_FOLDER}/f_topup_results_rads #from degree to rads

#averages over the 6 SE field maps with different phase encoding direction. Average will later be used as a field map magnitude input for epi_reg
fslmaths ${OUTPUT_FOLDER}/topup_unwarped -Tmean ${OUTPUT_FOLDER}/topup_unwarped_average
bet2 ${OUTPUT_FOLDER}/topup_unwarped_average ${OUTPUT_FOLDER}/topup_unwarped_average_brain

#corregisters the AP SBref (Single Band EPI) to the average of the three AP Spin Echo  
fslmaths $FMRI_FOLDER/${SE_GFM_AP} -Tmean ${OUTPUT_FOLDER}/SE_GFM_AP_mean
flirt -in $FMRI_FOLDER/${REF_FUNC} -ref ${OUTPUT_FOLDER}/SE_GFM_AP_mean -out ${OUTPUT_FOLDER}/SE_GFM_AP_mean_correg2GFM -omat ${OUTPUT_FOLDER}/SBref2GFM-ap.mat -dof 6

#Motion correction. Realigns to the reference single band EPI reference image
echo "Realigns to the reference single band EPI reference image"
#realignment to first image, which is set to be the SBref
fslmerge -t $OUTPUT_FOLDER/r$FMRI_ORIG $FMRI_FOLDER/${REF_FUNC} $OUTPUT_FOLDER/$FMRI_ORIG
mcflirt -in $OUTPUT_FOLDER/r$FMRI_ORIG -out $OUTPUT_FOLDER/r_realign -mats -plots -refvol 0

#run fmri to MRI registration with Field Map distortion and pre-realignment from SE to SBref.
epi_reg --epi=$FMRI_FOLDER/${REF_FUNC} --t1=$T1_FILE --t1brain=${OUTPUT_FOLDER}/T1_brain --out=${OUTPUT_FOLDER}/epi2t1  --fmap=${OUTPUT_FOLDER}/f_topup_results_rads --fmapmagbrain=${OUTPUT_FOLDER}/topup_unwarped_average_brain  --fmapmag=${OUTPUT_FOLDER}/topup_unwarped_average  --echospacing=0.0005 --pedir=-y

#applies warp to realigned&resliced
applywarp --in=$OUTPUT_FOLDER/r_realign --ref=${OUTPUT_FOLDER}/T1_brain --out=${OUTPUT_FOLDER}/cr$FMRI_ORIG --warp=${OUTPUT_FOLDER}/epi2t1_warp --premat=${OUTPUT_FOLDER}/SBref2GFM-ap.mat

