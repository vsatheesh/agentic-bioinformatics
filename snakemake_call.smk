# Script 14: Variant calling (through the VCF)

configfile: "config.yaml"

GENOME = config["genome"]
SAMPLES, = glob_wildcards(config["reads_dir"] + "/{sample}_R1.fastq.gz")

if not SAMPLES:
    raise WorkflowError(
        "No reads matching {sample}_R1.fastq.gz found in " + config["reads_dir"]
    )

rule all:
    input:
        expand(config["output_variants"] + "/{sample}.vcf.gz", sample=SAMPLES)

rule bwa_index:
    input:
        GENOME
    output:
        multiext(GENOME, ".0123", ".amb", ".ann", ".bwt.2bit.64", ".pac")
    shell:
        """
        module load bwa_mem2
        bwa-mem2 index {input}
        """

rule faidx:
    input:
        GENOME
    output:
        GENOME + ".fai"
    shell:
        """
        module load samtools
        samtools faidx {input}
        """

rule fastp:
    input:
        r1 = config["reads_dir"] + "/{sample}_R1.fastq.gz",
        r2 = config["reads_dir"] + "/{sample}_R2.fastq.gz"
    output:
        r1 = config["output_trim"] + "/{sample}_R1.trimmed.fastq.gz",
        r2 = config["output_trim"] + "/{sample}_R2.trimmed.fastq.gz",
        json = config["output_trim"] + "/{sample}.fastp.json",
        html = config["output_trim"] + "/{sample}.fastp.html"
    threads: 4
    resources:
        mem_mb = 4000,
        runtime = 30
    log:
        "logs/fastp/{sample}.log"
    shell:
        """
        module load fastp
        fastp -i {input.r1} -I {input.r2} -o {output.r1} -O {output.r2} \
            -w {threads} -j {output.json} -h {output.html} 2> {log}
        """

rule bwa_map:
    input:
        r1 = config["output_trim"] + "/{sample}_R1.trimmed.fastq.gz",
        r2 = config["output_trim"] + "/{sample}_R2.trimmed.fastq.gz",
        genome = GENOME,
        idx = multiext(GENOME, ".0123", ".amb", ".ann", ".bwt.2bit.64", ".pac")
    output:
        config["output_aligned"] + "/{sample}.sorted.bam"
    threads: 4
    resources:
        mem_mb = 8000,
        runtime = 60
    log:
        "logs/bwa_map/{sample}.log"
    shell:
        """
        module load bwa_mem2
        module load samtools
        bwa-mem2 mem -t {threads} -K 100000000 \
            -R '@RG\\tID:{wildcards.sample}\\tSM:{wildcards.sample}\\tPL:ILLUMINA' \
            {input.genome} {input.r1} {input.r2} 2> {log} \
            | samtools sort -@ {threads} -o {output}
        """

rule bam_index:
    input:
        config["output_aligned"] + "/{sample}.sorted.bam"
    output:
        config["output_aligned"] + "/{sample}.sorted.bam.bai"
    shell:
        """
        module load samtools
        samtools index {input}
        """

rule call:
    input:
        bam = config["output_aligned"] + "/{sample}.sorted.bam",
        bai = config["output_aligned"] + "/{sample}.sorted.bam.bai",
        genome = GENOME,
        fai = GENOME + ".fai"
    output:
        vcf = config["output_variants"] + "/{sample}.vcf.gz",
        csi = config["output_variants"] + "/{sample}.vcf.gz.csi"
    log:
        "logs/call/{sample}.log"
    shell:
        """
        module load bcftools
        bcftools mpileup -f {input.genome} -d 1000 -a AD,DP {input.bam} 2> {log} \
            | bcftools call -mv -Oz -o {output.vcf} 2>> {log}
        bcftools index {output.vcf} 2>> {log}
        """
