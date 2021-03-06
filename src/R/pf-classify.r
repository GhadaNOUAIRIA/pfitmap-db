#!/usr/bin/env Rscript

# pf-classify
#
# Author: daniel.lundin@dbb.su.se

suppressPackageStartupMessages(library(optparse))
suppressPackageStartupMessages(library(dplyr))
suppressPackageStartupMessages(library(readr))
suppressPackageStartupMessages(library(tidyr))
suppressPackageStartupMessages(library(stringr))

SCRIPT_VERSION = "1.9.2"

# Get arguments
option_list <- list(
  make_option(
    c('--dbsource'), default='', help='Database source in dbsource:name:version format'
  ),
  make_option(
    c('--fuzzy_factor'), type = 'integer', default = 1, action = 'store', help = 'Factor to make lengths fuzzy for reduction of possible duplicates, default %default.'
  ),
  make_option(
    c('--gtdbmetadata'), default = '', help = 'A concatenation of the bacterial (bac120_metadata.tsv) and archaeal (ar122_metadata.tsv) metadata files from GTDB. Make sure there is *only one header* line.',
  ),
  make_option(
    c('--hmm_mincov'), type = 'double', default = 0.0, action = 'store', help = 'Minimum coverage of hmm profile to include in output, default %default.'
  ),
  make_option(
  c('--profilehierarchies'), default='', help='A tsv file with profile hiearchies, including a header. Required fields: profile and plen, recommended psuperfamily, pfamily pclass, psubclass, pgroup, prank and version.'
  ),
  make_option(
    c('--seqfaa'), default='', help='Fasta file with amino acid sequences, same as the one used as database when hmmsearching. Will populate a sequence table if --sqlitedb is set.',
  ),
  make_option(
    c('--singletable'), default='', help='Write data in a single tsv format to this filename.'
  ),
  make_option(
    c('--sqlitedb'), default='', help='Write data in a SQLite database with this filename.'
  ),
  make_option(
    c('--taxflat'), default='', help='Name of NCBI taxon table in "taxflat" format (see https://github.com/erikrikarddaniel/taxdata2taxflat).'
  ),
  make_option(
    c("-v", "--verbose"), action="store_true", default=FALSE, 
    help="Print progress messages"
  ),
  make_option(
    c("-V", "--version"), action="store_true", default=FALSE, 
    help="Print program version and exit"
  )
)
opt <- parse_args(
  OptionParser(
    usage = "%prog [options] file0.tblout .. filen.tblout file0.domtblout .. filen.domtblout", 
    option_list = option_list
  ), 
  positional_arguments = TRUE
)

if ( opt$options$version ) {
  write(SCRIPT_VERSION[1], stdout())
  quit('no')
}

if ( length(grep('sqlitedb', names(opt$options), value = TRUE)) > 0 ) {
  suppressPackageStartupMessages(library(dbplyr))
}

# Args list for testing:
# NCBI: opt = list(args = c('pf-classify.00.d/GRX.ncbi_nr.test.domtblout', 'pf-classify.00.d/GRX.ncbi_nr.test.tblout', 'pf-classify.00.d/NrdAe.tblout','pf-classify.00.d/NrdAg.tblout','pf-classify.00.d/NrdAh.tblout','pf-classify.00.d/NrdAi.tblout','pf-classify.00.d/NrdAk.tblout','pf-classify.00.d/NrdAm.tblout','pf-classify.00.d/NrdAn.tblout','pf-classify.00.d/NrdAq.tblout','pf-classify.00.d/NrdA.tblout','pf-classify.00.d/NrdAz3.tblout','pf-classify.00.d/NrdAz4.tblout','pf-classify.00.d/NrdAz.tblout','pf-classify.00.d/NrdAe.domtblout','pf-classify.00.d/NrdAg.domtblout','pf-classify.00.d/NrdAh.domtblout','pf-classify.00.d/NrdAi.domtblout','pf-classify.00.d/NrdAk.domtblout','pf-classify.00.d/NrdAm.domtblout','pf-classify.00.d/NrdAn.domtblout','pf-classify.00.d/NrdAq.domtblout','pf-classify.00.d/NrdA.domtblout','pf-classify.00.d/NrdAz3.domtblout','pf-classify.00.d/NrdAz4.domtblout','pf-classify.00.d/NrdAz.domtblout'), options=list(verbose=T, singletable='test.out.tsv', hmm_mincov=0.9, profilehierarchies='pf-classify.00.phier.tsv', taxflat='pf-classify.taxflat.tsv', sqlitedb='testdb.sqlite3', dbsource='NCBI:NR:20180212', fuzzy_factor=30))
# GTDB: opt = list(args = c('pf-classify.gtdb.02.d/NrdA.domtblout', 'pf-classify.gtdb.02.d/NrdAe.domtblout', 'pf-classify.gtdb.02.d/NrdAe.tblout', 'pf-classify.gtdb.02.d/NrdAg.domtblout', 'pf-classify.gtdb.02.d/NrdAg.tblout', 'pf-classify.gtdb.02.d/NrdAh.domtblout', 'pf-classify.gtdb.02.d/NrdAh.tblout', 'pf-classify.gtdb.02.d/NrdAi.domtblout', 'pf-classify.gtdb.02.d/NrdAi.tblout', 'pf-classify.gtdb.02.d/NrdAk.domtblout', 'pf-classify.gtdb.02.d/NrdAk.tblout', 'pf-classify.gtdb.02.d/NrdAn.domtblout', 'pf-classify.gtdb.02.d/NrdAn.tblout', 'pf-classify.gtdb.02.d/NrdA.tblout', 'pf-classify.gtdb.02.d/NrdAz.domtblout', 'pf-classify.gtdb.02.d/NrdAz.tblout', 'pf-classify.gtdb.02.d/NrdF.domtblout', 'pf-classify.gtdb.02.d/NrdF.tblout'), options=list(verbose=T, singletable='test.out.tsv', hmm_mincov=0.9, profilehierarchies='pf-classify.gtdb.02.phier.tsv', taxflat='pf-classify.taxflat.tsv', sqlitedb='testdb.sqlite3', dbsource='GTDB:GTDB:r86', fuzzy_factor=30, gtdbannotindex='pf-classify.gtdb.02.d/gtdb_prokka_index.tsv.gz', gtdbmetadata='pf-classify.gtdb.02.d/gtdb_metadata.tsv', gtdbtaxonomy='pf-classify.gtdb.02.d/gtdb_taxonomy.tsv', seqfaa='pf-classify.gtdb.03.d/genomes.faa'))
DEBUG   = 0
INFO    = 1
WARNING = 2
LOG_LEVELS = list(
  DEBUG   = list(n = 0, msg = 'DEBUG'),
  INFO    = list(n = 1, msg = 'INFO'),
  WARNING = list(n = 2, msg = 'WARNING'),
  ERROR   = list(n = 3, msg = 'ERROR')
)
logmsg    = function(msg, llevel='INFO') {
  if ( opt$options$verbose | LOG_LEVELS[[llevel]][["n"]] >= LOG_LEVELS[["WARNING"]][["n"]] ) {
    write(
      sprintf("%s: %s: %s", llevel, format(Sys.time(), "%Y-%m-%d %H:%M:%S"), msg),
      stderr()
    )
  }
}
logmsg(sprintf("pf-classify.r version %s: Starting classification", SCRIPT_VERSION))

# Make sure the dbsource parameter is given and in the proper format
if ( opt$options[['dbsource']] != '' ) {
  dbsource <- strsplit(opt$options$dbsource, ':')[[1]]
} else {
  logmsg(sprintf("--dbsource is required"), 'ERROR')
  quit('no', status = 2)
}

if ( length(dbsource) != 3 ) {
  logmsg(sprintf("--dbsource needs to contain three components separated with ':', you specified '%s'", opt$options$dbsource), 'ERROR')
  quit('no', status = 2)
}

# Check if the GTDB metadata parameter is given
gtdb <- ifelse(opt$options$gtdbmetadata > '', TRUE, FALSE)

logmsg(sprintf("Reading profile hierarchies from %s", opt$options$profilehierarchies))
hmm_profiles <- read_tsv(opt$options$profilehierarchies, col_types = cols(.default=col_character(), plen = col_integer()))

# Read the taxonomy file, in GTDB or NCBI format
if ( gtdb ) {
  logmsg(sprintf('Reading GTDB metadata from %s', opt$options$gtdbmetadata))
  gtdbmetadata <- read_tsv(
    opt$options$gtdbmetadata,
    col_types = cols(.default = col_character())
  ) %>%
    mutate(
      thier = str_remove_all(gtdb_taxonomy, '[a-z]__'), 
    ) %>%
    separate(thier, c('tdomain', 'tphylum', 'tclass', 'torder', 'tfamily', 'tgenus', 'tspecies'), sep = ';')
  gtdbtaxonomy <- gtdbmetadata %>%
    mutate(
      accno0 = str_remove(accession, '^RS_') %>% str_remove('^GB_') %>% str_remove('\\.[0-9]'), 
      accno1 = ncbi_genbank_assembly_accession %>% str_remove('\\.[0-9]'),
      trank  = 'species',
      ncbi_taxon_id = ncbi_species_taxid
    ) %>%
    select(accno0, accno1, tdomain:tspecies, trank, ncbi_taxon_id)
} else {
  logmsg(sprintf("Reading NCBI taxonomy from %s", opt$options$taxflat))
  taxflat <- read_tsv(opt$options$taxflat, col_types=cols(.default=col_character(), ncbi_taxon_id=col_integer())) %>%
    transmute(
      ncbi_taxon_id, taxon, trank = rank,
      tdomain       = superkingdom, tkingdom = kingdom,
      tphylum       = phylum,       tclass   = class,
      torder        = order,        tfamily  = family,
      tgenus        = genus,        tspecies = species
    )

  # Delete duplicate taxon, rank combinations belonging in Eukaryota
  taxflat <- taxflat %>%
    anti_join(
      taxflat %>% group_by(taxon, trank) %>% summarise(n = n()) %>% ungroup() %>% filter(n > 1) %>%
        inner_join(taxflat %>% filter(tdomain == 'Eukaryota'), by = c('taxon', 'trank')),
      by = c('ncbi_taxon_id')
    )
}

# We will populate two tables, one with the full results, one with accessions
tblout <- tibble(
  accno = character(), profile = character(),
  evalue = double(), score = double(), bias = double()
)
accessions <- tibble(accno = character(), accto = character())

# Read all the tblout files
for ( tbloutfile in grep('\\.tblout', opt$args, value=TRUE) ) {
  logmsg(sprintf("Reading %s", tbloutfile))
  t =  read_fwf(
    tbloutfile, fwf_cols(content = c(1, NA)), 
    col_types = cols(content = col_character()), 
    comment='#'
  ) %>% 
    separate(
      content, 
      c('accno', 't0', 'profile', 't1', 'evalue', 'score', 'bias', 'f0', 'f1', 'f2', 'f3', 'f4', 'f5', 'f6', 'f7', 'f8', 'f9', 'f10', 'rest'), 
      '\\s+', 
      extra='merge',
      convert = T
    )
  tblout <- union(tblout, t %>% select(accno, profile, evalue, score, bias))
  accessions <- union(accessions, t %>% transmute(accno, accto = sprintf("%s %s", accno, rest)))
}

# Split the accto field
accessions <- accessions %>% separate_rows(accto, sep = '\x01') %>% 
  mutate(
    taxon = ifelse(
      grepl('[^[]\\[(.*)\\]', accto), 
      sub('.*[^[]\\[(.*)\\].*', '\\1', accto),
      'unknown'
    ),
    accto = sub(' .*', '', accto)
  )

domtblout <- tibble(
  accno = character(), tlen = integer(), profile = character(), qlen = integer(), i = integer(), n = integer(), 
  dom_c_evalue = double(), dom_i_evalue = double(), dom_score = double(), dom_bias = double(),
  hmm_from = integer(), hmm_to = integer(), ali_from = integer(), ali_to = integer(), 
  env_from = integer(), env_to = integer()
)

# Read all the domtblout files
for ( domtbloutfile in grep('\\.domtblout', opt$args, value=TRUE) ) {
  logmsg(sprintf("Reading %s", domtbloutfile))
  t <- read_fwf(
    domtbloutfile, fwf_cols(content = c(1, NA)), 
    col_types = cols(content = col_character()), 
    comment='#'
  ) %>% 
    separate(
      content, 
      c(
        'accno', 't0', 'tlen', 'profile', 't1', 'qlen',  'evalue', 'score', 'bias', 'i', 'n', 
        'dom_c_evalue', 'dom_i_evalue', 'dom_score', 'dom_bias', 
        'hmm_from', 'hmm_to', 'ali_from', 'ali_to', 'env_from', 'env_to', 'acc', 'rest'
      ),
      '\\s+', 
      extra='merge',
      convert = T
    )
  
  domtblout <- union(
    domtblout,
    t %>% select(
      accno, tlen, profile, qlen, i, n, dom_c_evalue, dom_i_evalue, dom_score, dom_bias,
      hmm_from, hmm_to, ali_from, ali_to, env_from, env_to
    )
  )
}

# Calculate lengths:
# This is long-winded because we have three lengths (hmm, ali and env) which
# have to be calculated separately after getting rid of overlapping rows in
# domtblout.

# Define a temporary table that will be filled with lengths, minimum from and maximum
# to values.
lengths <- tibble(
  accno = character(), profile = character(), type = character(), val = integer()
)

# Function that joins all with n > 1 with the next row and not occurring in the second
# table in the call.
do_nextjoin <- function(dt, no) {
  dt %>% 
    filter(n > 1) %>%
    left_join(
      domt %>% transmute(accno, profile, i = i - 1, next_row = TRUE, next_from = from, next_to = to), 
      by = c('accno', 'profile', 'i')
    ) %>%
    replace_na(list('next_row' = FALSE)) %>%
    return()
}

# FOR EACH FROM-TO PAIR:
for ( fs in list(
  c('hmm_from', 'hmm_to', 'hmmlen'),
  c('ali_from', 'ali_to', 'alilen'),
  c('env_from', 'env_to', 'envlen')
)) {
  logmsg(sprintf("Calculating %s", fs[3]))

  # 1. Set from and to to current pair, delete shorter rows with the same start and 
  # calculate i (rownumber) and n (total domains) for each combination of accno and profile
  domt <- domtblout %>% transmute(accno, profile, from = .data[[fs[1]]], to = .data[[fs[2]]]) 
  domt <- domt %>% distinct() %>%
    semi_join(
      domt %>% group_by(accno, profile, from) %>% filter(to == max(to)) %>% ungroup,
      by = c('accno', 'profile', 'from', 'to')
    ) %>% 
    arrange(accno, profile, from, to) %>%
    group_by(accno, profile) %>% mutate(i = row_number(from), n = n()) %>% ungroup()

  # This is where non-overlapping rows will be stored
  nooverlaps <- tibble(
    accno = character(), profile = character(),
    from = integer(), to = integer()
  )

  while ( domt %>% nrow() > 0 ) {
    logmsg(sprintf("Working on overlaps, nrow: %d", domt %>% nrow()))
    
    # 2. Move rows with n == 1 to nooverlaps
    nooverlaps <- nooverlaps %>%
      union(domt %>% filter(n == 1) %>% select(accno, profile, from, to))
    domt <- domt %>% filter(n > 1)
    
    nextjoin <- do_nextjoin(domt, nooverlaps)

    # As a debug aid, save the domt and nextjoin data sets
    #write_tsv(domt, 'domt.tsv.gz')
    #write_tsv(nextjoin, 'nextjoin.tsv.gz')
  
    # 3. Move rows that do not overlap with the next row
    nooverlaps <- nooverlaps %>%
      union(nextjoin %>% filter(to < next_from) %>% select(accno, profile, from, to))
    nextjoin <- nextjoin %>%
      anti_join(
        nextjoin %>% filter(to < next_from) %>% select(accno, profile, from, to),
        by = c('accno', 'profile', 'from', 'to')
      )
    
    # 4. Delete rows which are contained in the earlier row
    nextjoin <- nextjoin %>%
      anti_join(
        nextjoin %>% filter(from < next_from, to > next_to) %>%
          transmute(accno, profile, from = next_from, to = next_to),
        by = c('accno', 'profile', 'from', 'to')
      )
    
    # 5. Set a new "to" for those that overlap with the next row
    nextjoin <- nextjoin %>%
      mutate(to = ifelse(! is.na(next_from) & to >= next_from & next_to > to, next_to, to))
    
    # 6. Delete rows that are the last in their group of overlaps, they now have
    #   the same "to" as the previous row.
    nextjoin <- nextjoin %>%
      anti_join(
        nextjoin %>% select(accno, profile, from, to) %>% 
          inner_join(nextjoin %>% select(accno, profile, from, to), by = c('accno', 'profile', 'to')) %>% 
          filter(from.x != from.y) %>% 
          group_by(accno, profile, to) %>% summarise(from = max(from.x)) %>% ungroup(),
        by = c('accno', 'profile', 'from', 'to')
      )

    # 5. Calculate a new domt from nextjoin
    domt <- nextjoin %>% distinct(accno, profile, from, to) %>%
      group_by(accno, profile) %>% mutate(i = rank(from), n = n()) %>% ungroup()
  }
  
  lengths <- lengths %>%
    union(
      nooverlaps %>% mutate(len = to - from + 1) %>%
        group_by(accno, profile) %>% summarise(len = sum(len), from = min(from), to = max(to)) %>% ungroup() %>%
        gather(type, val, len, from, to) %>%
        mutate(
          type = case_when(
            type == 'len' ~ fs[3],
            type == 'from' ~ fs[1],
            type == 'to'   ~ fs[2]
          )
        )
    )
}

# Join in the above results with tlen and qlen from domtblout
align_lengths <- domtblout %>% distinct(accno, profile, tlen, qlen) %>%
  inner_join(lengths %>% spread(type, val, fill = 0), by = c('accno', 'profile'))

logmsg("Calculated lengths, inferring source databases from accession numbers")

if ( gtdb ) {
  accessions$db <- 'gtdb'
  accessions <- accessions %>%
    transmute(db, genome_accno = str_remove(taxon, '\\..*'), accno)
} else {
  # Infer databases from the structure of accession numbers
  accessions <- accessions %>%
    mutate(db = ifelse(grepl('^.._', accto), 'refseq', NA)) %>%
    mutate(db = ifelse((is.na(db) & grepl('^[0-9A-Z]{4,4}_[0-9A-Z]$', accto)), 'pdb', db)) %>%
    mutate(db = ifelse((is.na(db) & grepl('^P[0-9]+\\.[0-9]+$', accto)), 'uniprot', db)) %>%
    mutate(db = ifelse((is.na(db) & grepl('^[A-NR-Z][0-9][A-Z][A-Z0-9][A-Z0-9][0-9][A-Z][A-Z0-9][A-Z0-9][0-9]\\.[0-9]+$', accto)), 'uniprot', db)) %>%
    mutate(db = ifelse((is.na(db) & grepl('^[O,P,Q][0-9][A-Z0-9][A-Z0-9][0-9]\\.[0-9]+$', accto)), 'uniprot', db)) %>%
    mutate(db = ifelse((is.na(db) & grepl('^[A-NR-Z][0-9][A-Z][A-Z0-9][A-Z0-9][0-9]\\.[0-9]+$', accto)), 'uniprot', db)) %>%
    mutate(db = ifelse((is.na(db) & grepl('^[ADEKOJMNP][A-Z][A-Z][0-9]+\\.[0-9]+$', accto)), 'genbank', db)) %>%
    mutate(db = ifelse((is.na(db) & grepl('^[C][A-Z][A-Z][0-9]+\\.[0-9]+$', accto)), 'embl', db)) %>%
    mutate(db = ifelse((is.na(db) & grepl('^[BFGIL][A-Z][A-Z][0-9]+\\.[0-9]+$', accto)), 'dbj', db))
}

logmsg("Inferred databases, calculating best scoring profile for each accession")

# Create proteins with entries from tblout not matching hmm_profile entries with rank == 'domain'.
# Calculate best scoring profile for each accession
proteins <- tblout %>% 
  anti_join(hmm_profiles %>% filter(prank == 'domain'), by = 'profile') %>%
  group_by(accno) %>% top_n(1, score) %>% ungroup() %>%
  select(accno, profile, score, evalue)

logmsg("Calculated best scoring profiles, creating domains")

# Create table of domains as those that match domains specified in hmm_profiles
domains <- domtblout %>%
  transmute(
    accno, profile, i, n,
    dom_c_evalue, dom_i_evalue, dom_score,
    hmm_from, hmm_to,
    ali_from, ali_to,
    env_from, env_to
  ) 

# Join in lengths
logmsg(sprintf("Joining in lengths from domtblout, nrows before: %d", proteins %>% nrow()))
proteins <- proteins %>% inner_join(align_lengths, by = c('accno', 'profile'))

logmsg("Joined in lengths, writing data")

# Subset data with hmm_mincov parameter
logmsg(sprintf("Subsetting output to proteins and domains covering at least %f of the hmm profile", opt$options$hmm_mincov))

# 1. proteins table
#logmsg(sprintf("proteins before: %d", proteins %>% nrow()), 'DEBUG')
p <- proteins %>% 
  inner_join(hmm_profiles %>% select(profile, plen), by = 'profile') %>%
  filter(hmmlen/plen >= opt$options$hmm_mincov) %>%
  select(-plen)
#logmsg(sprintf("proteins after: %d", proteins %>% nrow()), 'DEBUG')
p <- p %>%
  union(
    proteins %>% anti_join(p, by = 'accno') %>%
      semi_join(accessions %>% filter(db == 'pdb'), by = c('accno' = 'accno'))
  )
proteins <- p
rm(p)

# 1.b add pdb entries that are not present due to not passing the hmm_mincov criterion

# 2. domains
domains <- domains %>%
  inner_join(hmm_profiles %>% select(profile, plen), by = 'profile') %>%
  filter((hmm_to - hmm_from + 1)/plen >= opt$options$hmm_mincov) %>%
  select(-plen)

# 3. accessions
accessions <- accessions %>% 
  semi_join(
    union(proteins %>% select(accno), domains %>% select(accno)) %>% distinct(accno), 
    by = 'accno'
  )

# 4. tblout
tblout <- tblout %>% semi_join(accessions %>% distinct(accno), by = 'accno')

# 5. domtblout
domtblout <- domtblout %>% semi_join(accessions %>% distinct(accno), by = 'accno')

# If we were called with the singletable option, prepare data suitable for that
if ( opt$options$singletable > '' ) {
  logmsg("Writing single table format")

  # Join proteins with accessions and drop profile to get a single table output
  logmsg(sprintf("Joining in all accession numbers and dropping profile column, nrows before: %d", proteins %>% nrow()))
  singletable <- proteins %>% 
    left_join(hmm_profiles, by='profile') %>%
    inner_join(accessions, by='accno') 
  
  if ( ! gtdb ) singletable <- singletable %>% mutate(accno = accto) 

  # Join in taxonomies, either GTDB or taxflat
  if ( gtdb ) {
    singletable <- union(
      singletable %>% inner_join(gtdbtaxonomy, by = c('genome_accno' = 'accno0')) %>% select(-accno1),
      singletable %>% anti_join(gtdbtaxonomy,  by = c('genome_accno' = 'accno0')) %>% left_join(gtdbtaxonomy, by = c('genome_accno' = 'accno1')) %>% select(-accno0)
    )
    if ( singletable %>% filter(is.na(tspecies)) %>% nrow() > 0 ) {
      logmsg(
        sprintf("*** Accessions without GTDB species assignment: %s ***", singletable %>% filter(is.na(tspecies)) %>% pull(genome_accno) %>% paste(collapse = ', ')),
        "WARNING"
      )
    }
    logmsg(sprintf("Writing single table %s, nrows: %d", opt$options$singletable, singletable %>% nrow()))
    write_tsv(
      singletable %>% 
        select(db, accno, score, evalue, profile, psuperfamily:pgroup, genome_accno, tdomain:tspecies, tlen, qlen, alilen, hmmlen,envlen) %>%
        arrange(accno, profile),
      opt$options$singletable
      )
  } else {
    logmsg(sprintf("Adding NCBI taxon ids from taxflat, nrows before: %d", singletable %>% nrow()))
    singletable <- singletable %>% 
      left_join(
        taxflat %>% select(taxon, ncbi_taxon_id),
        by='taxon'
      )
    logmsg(sprintf("Writing single table %s, nrows: %d", opt$options$singletable, singletable %>% nrow()))
    write_tsv(
      singletable %>% 
        select(db, accno, taxon, score, evalue, profile, psuperfamily:pgroup, ncbi_taxon_id, tlen, qlen, alilen, hmmlen,envlen) %>%
        arrange(accno, profile),
      opt$options$singletable
      )
  }
}

# If the user specified a filename for a SQLite database, write that here
if ( length(grep('sqlitedb', names(opt$options), value = TRUE)) > 0 & str_length(opt$options$sqlitedb) > 0 ) {
  logmsg(sprintf("Creating/opening SQLite database %s", opt$options$sqlitedb))
  con <- DBI::dbConnect(RSQLite::SQLite(), opt$options$sqlitedb, create = TRUE)

  con %>% copy_to(
    tibble(source = dbsource[1], name = dbsource[2], version = dbsource[3]), 
    'dbsources', temporary = FALSE, overwrite = TRUE
  )

  if ( ! gtdb ) {
    # The accto field in accession should be turned into a list for each
    # combination of accno, db and taxon to ensure organisms do not show up as
    # having more than one exactly identical sequence, which they do with the new
    # redundant RefSeq entries (WP_ accessions).
    logmsg('Copying to "accessions", creating indices')
    accessions <- accessions %>%
      arrange(db, taxon, accno, accto) %>%
      group_by(db, taxon, accno) %>%
      summarise(accto = paste(accto, collapse = ',')) %>%
      ungroup() %>%
      separate_rows(accto, sep = ',') %>%
      distinct()
  }
  
  con %>% copy_to(accessions, 'accessions', temporary = FALSE, overwrite = TRUE)
  con %>% DBI::dbExecute('CREATE INDEX "accessions.i00" ON "accessions"("accno");')
  if ( gtdb ) {
    con %>% DBI::dbExecute('CREATE INDEX "accessions.i01" ON "accessions"("db", "accno", "genome_accno");')
    con %>% DBI::dbExecute('CREATE INDEX "accessions.i02" ON "accessions"("genome_accno");')
  } else {
    con %>% DBI::dbExecute('CREATE INDEX "accessions.i01" ON "accessions"("db", "accto", "taxon");')
    con %>% DBI::dbExecute('CREATE INDEX "accessions.i02" ON "accessions"("taxon");')
  }
  
  logmsg('Copying to "proteins", creating indices')
  con %>% copy_to(proteins, 'proteins', temporary = FALSE, overwrite = TRUE)
  con %>% DBI::dbExecute('CREATE INDEX "proteins.i00" ON "proteins"("accno");')
  con %>% DBI::dbExecute('CREATE INDEX "proteins.i01" ON "proteins"("profile");')

  logmsg('Copying to "domains", creating indices')
  con %>% copy_to(domains, 'domains', temporary = FALSE, overwrite = TRUE)
  con %>% DBI::dbExecute('CREATE INDEX "domains.i00" ON "domains"("accno");')
  con %>% DBI::dbExecute('CREATE INDEX "domains.i01" ON "domains"("profile");')

  logmsg('Copying to "hmm_profiles", creating indices')
  con %>% copy_to(hmm_profiles, 'hmm_profiles', temporary = FALSE, overwrite = TRUE)
  con %>% DBI::dbExecute('CREATE UNIQUE INDEX "hmm_profiles.i00" ON "hmm_profiles"("profile");')

  logmsg('Copying to "taxa", creating indices')
  if ( gtdb ) {
    con %>% copy_to(
      union(
        gtdbtaxonomy %>% semi_join(accessions, by = c('accno0' = 'genome_accno')) %>% 
          select(-accno1) %>% rename(genome_accno = accno0),
        gtdbtaxonomy %>% anti_join(accessions, by = c('accno0' = 'genome_accno')) %>% 
          mutate(genome_accno = ifelse(accno1 == 'none', accno0, accno1)) %>%
          select(-accno0, -accno1)
      ),
      'taxa', temporary = FALSE, overwrite = TRUE
    )
    
    con %>% DBI::dbExecute('CREATE UNIQUE INDEX "taxa.i00" ON "taxa"("genome_accno");')
  } else {
    # If we have a taxflat NCBI taxonomy, read and join
    logmsg(sprintf("Adding NCBI taxon ids from taxflat"))
    con %>% copy_to(
      taxflat %>% semi_join(accessions %>% distinct(taxon), by='taxon'),
      'taxa', temporary = FALSE, overwrite = TRUE
    )

    con %>% DBI::dbExecute('CREATE UNIQUE INDEX "taxa.i00" ON "taxa"("taxon", "trank");')
    con %>% DBI::dbExecute('CREATE UNIQUE INDEX "taxa.i01" ON "taxa"("ncbi_taxon_id");')
  }

  logmsg('Saving tblout and domtblout to database')
  con %>% copy_to(tblout    %>% arrange(accno, profile),    'tblout',    temporary = FALSE, overwrite = TRUE)
  con %>% copy_to(domtblout %>% arrange(accno, profile, i), 'domtblout', temporary = FALSE, overwrite = TRUE)

  if ( ! gtdb ) {
  logmsg(sprintf('Creating dupfree_proteins, using %d as fuzzy factor', opt$options$fuzzy_factor))
    dp <- proteins %>% inner_join(accessions %>% transmute(accno = accto, db, taxon), by = 'accno') %>%
      mutate(
        alilen = as.integer(round(round(alilen / opt$options$fuzzy_factor) * opt$options$fuzzy_factor)),
        envlen = as.integer(round(round(envlen / opt$options$fuzzy_factor) * opt$options$fuzzy_factor)),
        hmmlen = as.integer(round(round(hmmlen / opt$options$fuzzy_factor) * opt$options$fuzzy_factor))
      ) %>%
      group_by(db, taxon, profile, alilen, hmmlen, envlen) %>% mutate(r = rank(accno)) %>% ungroup()

    con %>% copy_to(
      dp %>% filter(r < 2) %>% select(-db, -taxon),
      'dupfree_proteins',
      temporary = FALSE, overwrite = TRUE
    )
  }

  if ( opt$options$seqfaa != '' ) {
    logmsg(sprintf('Reading %s and saving sequences table', opt$options$seqfaa))
    s <- Biostrings::readAAStringSet(opt$options$seqfaa)
    s <- tibble(accno = str_remove(names(s), ' .*'), sequence = as.character(s)) %>%
      distinct()
    con %>% copy_to(
      s %>% semi_join(accessions, by = 'accno'),
      'sequences',
      temporary = FALSE, overwrite = TRUE
    )
    con %>% DBI::dbExecute('CREATE UNIQUE INDEX "sequences.i00" ON "sequences"("accno");')
  }

  logmsg('Disconnecting from sqlite3 db')
  con %>% DBI::dbDisconnect()
}

logmsg("Done")
