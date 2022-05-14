*** common primers we used
341F: CCTACGGGAGGCAGCAG	
515F: GTGCCAGCMGCCGCGGTAA
806R: GGACTACNVGGGTWTCTAAT

ITS1: CTTGGTCATTTAGAGGAAGTAA
ITS4: TCCTCCGCTTATTGATATGC

####The current use to cut the primers for individual files (modify the primer sequences according your primers applied)

for file in `find . -name "*R1*fastq.gz"`;         do         fastaFile=${file}; cutadapt -g CCTACGGGAGGCAGCAG -o ${fastaFile}_trimmed.fastq.gz ${fastaFile}; done

for file in `find . -name "*R2*fastq.gz"`;         do         fastaFile=${file}; cutadapt -g GGACTACNVGGGTWTCTAAT -o ${fastaFile}_trimmed.fastq.gz ${fastaFile}; done



####Qiime2

##Get into Qiime:
source activate qiime2-2020.2
source tab-qiime

#####input your data into qiime2 (single-end or paired-end)
### data input for single end

qiime tools import \
--type 'SampleData[SequencesWithQuality]' \
--input-path trimmed_seq \
--input-format CasavaOneEightSingleLanePerSampleDirFmt \
--output-path demux-single-end.qza


### data input for paired-end
qiime tools import \
  --type 'SampleData[PairedEndSequencesWithQuality]' \
  --input-path trimmed_seq \
  --input-format CasavaOneEightSingleLanePerSampleDirFmt \
  --output-path demux-paired-end.qza
  
  
qiime tools import \
  --type 'SampleData[PairedEndSequencesWithQuality]' \
  --input-path trimmed_seq/manifest.txt \
  --input-format PairedEndFastqManifestPhred33V2 \
  --output-path demux-paired-end.qza
  
qiime tools import  \
   --type 'SampleData[SequencesWithQuality]' \
   --input-path trimmed_seq/manifest.txt \
   --output-path single-end-demux.qza   \
   --input-format SingleEndFastqManifestPhred33V2

####check QC 
qiime demux summarize \
--i-data demux-single-end.qza \
--o-visualization summarized-demux.qzv

qiime tools view summarized-demux.qzv


####dada2 denoise single end 
#the number of "--p-trunc-len" defines the minimum sequence length 

qiime dada2 denoise-single \
--i-demultiplexed-seqs demux-single-end.qza \
--p-trunc-len 240 \ ####set this len threshold based on the QC 
--p-n-threads 0 \
--o-denoising-stats stats1.qza \
--o-table table1 \
--o-representative-sequences rep1

###for paired-end 
(qiime dada2 denoise-paired \
 --i-demultiplexed-seqs demux-single-end.qza \
--p-trunc-len-f 240 \ ####set this len threshold based on the QC 
--p-trunc-len-r 240
--p-n-threads 0 \
--o-denoising-stats stats1.qza \
--o-table table1 \
--o-representative-sequences rep1)



qiime metadata tabulate \
  --m-input-file stats1.qza \
  --o-visualization stats1.qzv


qiime feature-table summarize \
--i-table table1.qza \
--o-visualization table1.qzv \
--m-sample-metadata-file sample-metadata.txt 


qiime tools view table1.qzv

(can view the single read counts)

 qiime feature-table tabulate-seqs \
  --i-data rep1.qza \
  --o-visualization rep1.qzv


qiime tools view rep1.qzv

qiime vsearch cluster-features-de-novo \
--i-sequences rep1.qza \
--i-table table1.qza \
--p-perc-identity 0.99 \ ####(0.97 and 0.99 for OTU; 1 for ASV)
--o-clustered-table 99_OTU_table.qza \
--o-clustered-sequences 99_OTU_seq.qza


qiime feature-table summarize \
--i-table 99_OTU_table.qza \
--m-sample-metadata-file sample-metadata.txt \
--o-visualization 99_vsearch_visual.qzv

qiime tools view 99_vsearch_visual.qzv



qiime feature-table tabulate-seqs \
  --i-data 99_OTU_seq.qza \
  --o-visualization 99_OTU_seq.qzv


qiime tools view 99_OTU_seq.qzv




###import the .fasta file (the reference sequences)(Website:https://docs.qiime2.org/2018.6/data-resources/)
####choose appropriate references for your study

##99% threshold
qiime tools import \
  --type 'FeatureData[Sequence]' \
  --input-path 99_otus.fasta \
  --output-path 99_otus_ref.qza
  
qiime tools import \
  --type 'FeatureData[Taxonomy]' \
  --input-format HeaderlessTSVTaxonomyFormat \
  --input-path 99_taxonomy.txt \
  --output-path 99_ref-taxonomy.qza
  
#70% Taxonomic assignment using Blast+

qiime feature-classifier classify-consensus-blast \
--i-query 99_OTU_seq.qza \
--i-reference-reads 99_otus_ref.qza \
--i-reference-taxonomy 99_ref-taxonomy.qza \
--p-maxaccepts 10 \
--p-perc-identity 0.70 \ ###adjust identity threshold based on your study
--p-min-consensus 0.51 \
--o-classification 99_taxonomy_blast.qza

#visualization of the taxonomic assignment

qiime metadata tabulate \
  --m-input-file 99_taxonomy_blast.qza \
  --o-visualization 99_taxonomy_blast.qzv

qiime tools view 99_taxonomy_blast.qzv

#Barplot

qiime taxa barplot \
  --i-table 99_OTU_table.qza \
  --i-taxonomy 99_taxonomy_blast.qza \
  --m-metadata-file sample-metadata.txt \
  --o-visualization 99_barplot_blast.qzv

qiime tools view 99_barplot_blast.qzv

##filter unidentified taxa
 qiime taxa filter-table \
  --i-table 99_OTU_table.qza \
  --i-taxonomy 99_taxonomy_blast.qza \
  --p-exclude Unassigned,Protista,Viridiplantae,k__unidentified \
  --p-mode contains \
  --o-filtered-table 99_table_no_Unassigned.qza

qiime taxa barplot \
  --i-table 99_table_no_Unassigned.qza \
  --i-taxonomy 99_taxonomy_blast.qza \
  --m-metadata-file sample-metadata.txt \
  --o-visualization 99_barplot_blast_filtered.qzv


###Obtaining the OTU table###

##To obtain relative frequency table at different taxonomic levels by adjust level number 
(1-7 correspond to kingdom to species)##


qiime taxa collapse --i-table 99_OTU_table.qza --i-taxonomy 99_taxonomy_blast.qza --p-level 6 --o-collapsed-table collapsed-tablelevel6.qza

qiime feature-table relative-frequency --i-table collapsed-tablelevel6.qza --o-relative-frequency-table collapsed-tablelevel6relativefrequency.qza

qiime tools export --input-path collapsed-tablelevel6relativefrequency.qza --output-path collapsed-tablelevel6relativefrequency
biom convert -i collapsed-tablelevel6relativefrequency/feature-table.biom -o table_level6.tsv --to-tsv


##To obtain relative frequency table at different taxonomic levels after filtering##

qiime taxa collapse --i-table 99_table_no_Unassigned.qza --i-taxonomy 99_taxonomy_blast.qza --p-level 6 --o-collapsed-table collapsed-tablelevel6.qza

qiime feature-table relative-frequency --i-table collapsed-tablelevel6.qza --o-relative-frequency-table collapsed-tablelevel6relativefrequency.qza

qiime tools export --input-path collapsed-tablelevel6relativefrequency.qza --output-path collapsed-tablelevel6relativefrequency
biom convert -i collapsed-tablelevel6relativefrequency/feature-table.biom -o table_level6_filter.tsv --to-tsv


### OTU table for R run
 
qiime tools export --input-path 99_OTU_table.qza --output-path otu_table
biom convert -i otu_table/feature-table.biom -o otu_table.tsv --to-tsv


###diversity analyses

*Generate a tree for phylogenetic diversity analyses*

qiime alignment mafft \
  --i-sequences 99_OTU_seq.qza \
  --o-alignment aligned-rep-seqs.qza
  

qiime alignment mask \
  --i-alignment aligned-rep-seqs.qza \
  --o-masked-alignment masked-aligned-rep-seqs.qza
  
qiime phylogeny fasttree \
  --i-alignment masked-aligned-rep-seqs.qza \
  --o-tree unrooted-tree.qza
  
qiime phylogeny midpoint-root \
  --i-tree unrooted-tree.qza \
  --o-rooted-tree rooted-tree.qza
  
qiime diversity core-metrics-phylogenetic \
  --i-phylogeny rooted-tree.qza \
  --i-table 99_OTU_table.qza \
  --p-sampling-depth 28000 \###rarefy the sequences based on the minimum sequences depth of samples
  --m-metadata-file sample-metadata.txt \
  --output-dir core-metrics-results

##View beta diversity

qiime tools view core-metrics-results/unweighted_unifrac_emperor.qzv

qiime tools view core-metrics-results/weighted_unifrac_emperor.qzv

qiime tools view core-metrics-results/jaccard_emperor.qzv

qiime tools view core-metrics-results/bray_curtis_emperor.qzv


## beta diversity signifcance ##

qiime diversity beta-group-significance \
--i-distance-matrix core-metrics-results/bray_curtis_distance_matrix.qza \
--m-metadata-file sample-metadata.txt \
--m-metadata-column Harvest \###adjust the factor according to the aim of your study
--o-visualization core-metrics-results/bray_curtis-Harvest-significance.qzv \
--p-pairwise



**Alpha and beta diversity analysis


**Alpha diversity analysis

###faith_pd

qiime diversity alpha-group-significance \
  --i-alpha-diversity core-metrics-results/faith_pd_vector.qza \
  --m-metadata-file sample-metadata.txt \
  --o-visualization core-metrics-results/faith-pd-group-significance.qzv
  
qiime tools view core-metrics-results/faith-pd-group-significance.qzv



###evenness

qiime diversity alpha-group-significance \
  --i-alpha-diversity core-metrics-results/evenness_vector.qza \
  --m-metadata-file sample-metadata.txt \
  --o-visualization core-metrics-results/evenness-group-significance.qzv
  
qiime tools view core-metrics-results/evenness-group-significance.qzv 


###shannon index
 qiime diversity alpha-group-significance \
  --i-alpha-diversity core-metrics-results/shannon_vector.qza \
  --m-metadata-file sample-metadata.txt \
  --o-visualization core-metrics-results/shannon-group-significance.qzv
  
  qiime tools view core-metrics-results/shannon-group-significance.qzv
  
## alpha rarefaction
qiime diversity alpha-rarefaction \
  --i-table table1.qza \
  --i-phylogeny rooted-tree.qza \
  --p-max-depth 100000 \
  --m-metadata-file sample-metadata.txt \
  --o-visualization alpha-rarefaction.qzv
  
  qiime tools view alpha-rarefaction.qzv