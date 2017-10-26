# Document Alignment step of the Parallel Data Extraction Workflow.
#
# Author: Radu ION, Research Institute for AI, Romanian Academy (RACAI)
#
# ver 0.1, 30-Aug-11, Radu ION: created.
# ver 0.2, 30-Aug-11, Radu ION: fixed ComMetric bug with temporary files.
# ver 0.3, 07-Jun-12, Mârcis Pinnis: ported updates from ParallelDataMining.pl ver 2.1.

use strict;
use warnings;

sub getFullLanguageName( $ );
sub absolutePathDocuments( $ );
sub readPropertyFile( $ );
sub normalizeLang( $ );
sub readCmdLineArguments( @ );
#ComMetric does alignments from Non-English to English only (so does the Feature Classifier).
sub swapDocumentAlignments( $ );

if ( scalar( @ARGV ) == 0 ) {
	die( "Usage: DocumentAlignment.pl 
	--source <language> --target <language>
	--param CONFIG=path\\to\\config.prop
	--param DOCALIGN=<dictmetric|commetric|emacc|featclass>
	--input <path to source documents file>
	--input <path to target documents file>
	--output <path to the document alignment file>\n" );
}

my( $pdataminingconf ) = readCmdLineArguments( @ARGV );
my( $docaligntool ) = $pdataminingconf->{"DOCALIGN"};

#Some document alignment tools know to align from Non-English to English only.
#Thus if alignment is requested from English to Non-English, we must swap the obtained alignments.
my( %SWAP_DOCUMENT_ALIGNMENTS ) = (
	"commetric" => 0,
	"emacc" => 0,
	"dictmetric" => 0,
	"featclass" => 0
);
#java, perl must be accesible from the %PATH%.
my( %DOCUMENT_ALIGNMENT_TOOLS ) = (
	#CTS ComMetric
	"commetric" => {
		"COMMAND" => "java -jar commetric\\ComMetric.jar",
		"ARGS" => [
			"--source " . do {
				my( $lang ) = $pdataminingconf->{"SRCL"};
				
				die( "DocumentAlignment::main: 'commetric' document alignment tool must have one English side !\n" )
					if ( $pdataminingconf->{"SRCL"} ne "en" && $pdataminingconf->{"TRGL"} ne "en" && $docaligntool eq "commetric" );
				
				if ( $pdataminingconf->{"SRCL"} eq "en" ) {
					$lang = $pdataminingconf->{"TRGL"};
					$SWAP_DOCUMENT_ALIGNMENTS{"commetric"} = 1;
				}
				
				uc( getFullLanguageName( $lang ) );
			},
			"--target " . do {
				my( $lang ) = $pdataminingconf->{"TRGL"};
				
				if ( $pdataminingconf->{"SRCL"} eq "en" ) {
					$lang = $pdataminingconf->{"SRCL"};
					$SWAP_DOCUMENT_ALIGNMENTS{"commetric"} = 1;
				}
				
				uc( getFullLanguageName( $lang ) );
			},
			"--WN \"" . $pdataminingconf->{"CONFIG"}->{"ComMetric_WN"} . "\"",
			"--threshold " . $pdataminingconf->{"CONFIG"}->{"ComMetric_Threshold"},
			"--translationAPI " . $pdataminingconf->{"CONFIG"}->{"ComMetric_TranslationAPI"},
			"--input " . do {
				my( $input1 ) = $pdataminingconf->{"INPUTFILE1"};
				
				if ( $pdataminingconf->{"SRCL"} eq "en" ) {
					$input1 = $pdataminingconf->{"INPUTFILE2"};
				}
				
				$input1;
			},
			"--input " . do {
				my( $input2 ) = $pdataminingconf->{"INPUTFILE2"};
				
				if ( $pdataminingconf->{"SRCL"} eq "en" ) {
					$input2 = $pdataminingconf->{"INPUTFILE1"};
				}
				
				$input2;
			},
			"--output " . $pdataminingconf->{"OUTPUTFILE"},
			"--tempDir " . do {
				my( $tmpdir ) = $pdataminingconf->{"CONFIG"}->{"ComMetric_TempDir"};

				#Clean up
				qx/del \/F \/Q \/S ${tmpdir}\\/;
				$tmpdir;
			}
		]
	},

	#CTS DictMetric
	"dictmetric" => {
		"COMMAND" => "java -jar dictmetric\\DictMetric.jar",
		"ARGS" => [
			"--source " . do {
				my( $lang ) = $pdataminingconf->{"SRCL"};
				
				if ( $pdataminingconf->{"SRCL"} eq "en" ) {
					$lang = $pdataminingconf->{"TRGL"};
					$SWAP_DOCUMENT_ALIGNMENTS{"dictmetric"} = 1;
				}
				
				lc( getFullLanguageName( $lang ) );
			},
			"--target " . do {
				my( $lang ) = $pdataminingconf->{"TRGL"};
				
				if ( $pdataminingconf->{"SRCL"} eq "en" ) {
					$lang = $pdataminingconf->{"SRCL"};
					$SWAP_DOCUMENT_ALIGNMENTS{"dictmetric"} = 1;
				}
				
				lc( getFullLanguageName( $lang ) );
			},
			"--WN \"" . $pdataminingconf->{"CONFIG"}->{"DictMetric_WN"} . "\"",
			"--threshold " . $pdataminingconf->{"CONFIG"}->{"DictMetric_Threshold"},
			"--input " . do {
				my( $input1 ) = $pdataminingconf->{"INPUTFILE1"};
				
				if ( $pdataminingconf->{"SRCL"} eq "en" ) {
					$input1 = $pdataminingconf->{"INPUTFILE2"};
				}
				
				$input1;
			},
			"--input " . do {
				my( $input2 ) = $pdataminingconf->{"INPUTFILE2"};
				
				if ( $pdataminingconf->{"SRCL"} eq "en" ) {
					$input2 = $pdataminingconf->{"INPUTFILE1"};
				}
				
				$input2;
			},
			"--output " . $pdataminingconf->{"OUTPUTFILE"},
			"--tempDir " . do {
				my ( $tmpdir ) = $pdataminingconf->{"CONFIG"}->{"DictMetric_TempDir"};
				
				#Clean up
				qx/del \/F \/Q \/S ${tmpdir}\\/;
				$tmpdir;
			},
			"--option " . $pdataminingconf->{"CONFIG"}->{"DictMetric_Option"}
		]
	},
	
	#RACAI EMACC
	"emacc" => {
		"COMMAND" => "perl emacc\\emacc2.pl",
		"ARGS" => [ 
			"--source " . $pdataminingconf->{"SRCL"},
			"--target " . $pdataminingconf->{"TRGL"},
			"--param EMLOOPS=" . $pdataminingconf->{"CONFIG"}->{"EMACC_EMLOOPS"},
			"--param MAXTARGETALIGNMENTS=" . $pdataminingconf->{"CONFIG"}->{"EMACC_MAXTARGETALIGNMENTS"},
			"--param INIDISTRIB=" . $pdataminingconf->{"CONFIG"}->{"EMACC_INIDISTRIB"},
			"--param TEQPUPDATETHR=" . $pdataminingconf->{"CONFIG"}->{"EMACC_TEQPUPDATETHR"},
			"--param LEXALSCORE=" . $pdataminingconf->{"CONFIG"}->{"EMACC_LEXALSCORE"},
			"--param PROBTYPE=" . $pdataminingconf->{"CONFIG"}->{"EMACC_PROBTYPE"},
			"--param DICTINVERSE=0",
			"--param CLUSTERFILE=" . $pdataminingconf->{"CONFIG"}->{"EMACC_CLUSTERFILE"},
			"--input " . $pdataminingconf->{"INPUTFILE1"},
			"--input " . $pdataminingconf->{"INPUTFILE2"},
			"--output " . $pdataminingconf->{"OUTPUTFILE"}
		]
	},
	
	#USFD Feature-based Document Pair Classifier
	#Uses Google Translate which does not work.
	#Not in use until a fix is available.
	"featclass" => {
		"COMMAND" => "echo ParallelDataMining::main: 'featclass' needs an upgrade. Will not run it.",
		"ARGS" => []
	},
	
	#"featclass" => {
	#	"COMMAND" => "featclass.bat",
	#	"ARGS" => [
	#		"--source " . do {
	#			my( $windirmodelscmd ) = "dir /B " . $pdataminingconf->{"CONFIG"}->{"FeatClass_Models"};
	#			my( @windirmodels ) = qx/$windirmodelscmd/;
	#			my( $foundlangpair ) = 0;
	#			
	#			MODELS:
	#			foreach my $m ( @windirmodels ) {
	#				$m =~ s/^\s+//;
	#				$m =~ s/\s+$//;
	#				
	#				my( @toks ) = split( /(?:\W|_)+/, $m );
	#				
	#				for ( my $i = 0; $i < scalar( @toks ); $i++ ) {
	#					if ( $toks[$i] =~ /^(en|ro|sl|lt|lv|hr|et|el|de)$/i && $toks[$i + 1] =~ /^(en|ro|sl|lt|lv|hr|et|el|de)$/i ) {
	#						if ( lc( $toks[$i] ) eq $pdataminingconf->{"SRCL"} && lc( $toks[$i + 1] ) eq $pdataminingconf->{"TRGL"} ) {
	#							$foundlangpair = 1;
	#							last MODELS;
	#						}
	#					}
	#				}
	#			}
	#			
	#			die( "ParallelDataMining::main: no '" . $pdataminingconf->{"SRCL"} . "-" . $pdataminingconf->{"TRGL"} . "' models in 'featclass' models directory !\n" )
	#				if ( ! $foundlangpair && $selecteddocaligntool eq "featclass" );
	#			
	#			getFullLanguageName( $pdataminingconf->{"SRCL"} )
	#		},
	#		"--target " . getFullLanguageName( $pdataminingconf->{"TRGL"} ),
	#		"--param threshold=" . $pdataminingconf->{"CONFIG"}->{"FeatClass_Threshold"},
	#		"--input " . do {
	#			die( "ParallelDataMining::main: 'featclass' requires lists of documents with absolute paths (first --input) !\n" )
	#				if ( ! absolutePathDocuments( $pdataminingconf->{"INPUTFILE1"} ) && $selecteddocaligntool eq "featclass" );
	#
	#			my( $crtdir ) = qx/echo %CD%/;
	#			
	#			$crtdir =~ s/^\s+//;
	#			$crtdir =~ s/\s+$//;
	#			
	#			$crtdir . "\\" . $pdataminingconf->{"INPUTFILE1"} if ( $pdataminingconf->{"INPUTFILE1"} !~ /^[A-Z]:\\/ );
	#		},
	#		"--input " . do {
	#			die( "ParallelDataMining::main: 'featclass' requires lists of documents with absolute paths (second --input) !\n" )
	#				if ( ! absolutePathDocuments( $pdataminingconf->{"INPUTFILE2"} ) && $selecteddocaligntool eq "featclass" );
	#			
	#			my( $crtdir ) = qx/echo %CD%/;
	#			
	#			$crtdir =~ s/^\s+//;
	#			$crtdir =~ s/\s+$//;
	#			
	#			$crtdir . "\\" . $pdataminingconf->{"INPUTFILE2"} if ( $pdataminingconf->{"INPUTFILE2"} !~ /^[A-Z]:\\/ );
	#		},
	#		"--output " . $pdataminingconf->{"OUTPUTFILE"}
	#	]
	#}
);

#1. DOCUMENT ALIGNMENT STEP.
warn( "DocumentAlignment::main: running '$docaligntool' document aligner ...\n\n" );
warn( "############## Tool Output ##################################\n\n" );
		
my( $cmdline ) = "";
	
$cmdline .= $DOCUMENT_ALIGNMENT_TOOLS{$docaligntool}->{"COMMAND"} . " ";
$cmdline .= join( " ", @{ $DOCUMENT_ALIGNMENT_TOOLS{$docaligntool}->{"ARGS"} } );
		
warn( $cmdline . "\n\n" );
system( $cmdline );
swapDocumentAlignments( $pdataminingconf->{"OUTPUTFILE"} ) if ( $SWAP_DOCUMENT_ALIGNMENTS{$docaligntool} );

warn( "\n############## End Tool Output ##############################\n\n" );
warn( "DocumentAlignment::main: end '$docaligntool' document aligner.\n\n" );

#END MAIN.

sub readCmdLineArguments( @ ) {
	my( @args ) = @_;
	my( %clconf ) = ();
	my( %allowedparams ) = (
		"CONFIG" => 1,
		"DOCALIGN" => 1
	);
	my( $input ) = 0;

	while ( scalar( @args ) > 0 ) {
		my( $opt ) = shift( @args );

		SWOPT: {
			$opt eq "--source" and do {
				$clconf{"SRCL"} = normalizeLang( shift( @args ) );
				last;
			};

			$opt eq "--target" and do {
				$clconf{"TRGL"} = normalizeLang( shift( @args ) );
				last;
			};

			$opt eq "--param" and do {
				my( $param, $value ) = split( /\s*=\s*/, shift( @args ) );

				$param = uc( $param );
				
				die( "DocumentAlignment::readCmdLineArguments: unknown parameter '$param' !\n" )
					if ( ! exists( $allowedparams{$param} ) );

				$clconf{$param} = $value;
				last;
			};

			$opt eq "--input" and do {
				$input++;
				$clconf{"INPUTFILE$input"} = shift( @args );
				last;
			};

			$opt eq "--output" and do {
				$clconf{"OUTPUTFILE"} = shift( @args );
				last;
			};

			die( "DocumentAlignment::readCmdLineArguments: unknown option '$opt' !\n" );
        }
	}
	
	die( "DocumentAlignment::readCmdLineArguments: required '--source' switch not present !\n" )
		if ( ! exists( $clconf{"SRCL"} ) );

	die( "DocumentAlignment::readCmdLineArguments: required '--target' switch not present !\n" )
		if ( ! exists( $clconf{"TRGL"} ) );
	
	die( "DocumentAlignment::readCmdLineArguments: required '--param DOCALIGN' switch not present !\n" )
		if ( ! exists( $clconf{"DOCALIGN"} ) );
		
	$clconf{"DOCALIGN"} = lc( $clconf{"DOCALIGN"} );

	die( "DocumentAlignment::readCmdLineArguments: DOCALIGN '" . $clconf{"DOCALIGN"} . "' is not a known value !\n" )
		if ( $clconf{"DOCALIGN"} !~ /^(commetric|emacc|featclass|dictmetric)$/ );
		
	die( "DocumentAlignment::readCmdLineArguments: a required '--input' switch is not present !\n" )
		if ( ! exists( $clconf{"INPUTFILE1"} ) || ! exists( $clconf{"INPUTFILE2"} ) );
	
	die( "DocumentAlignment::readCmdLineArguments: required '--output' switch not present !\n" )
		if ( ! exists( $clconf{"OUTPUTFILE"} ) );
	
	#Read in the property file.
	if ( exists( $clconf{"CONFIG"} ) ) {
		$clconf{"CONFIG"} = readPropertyFile( $clconf{"CONFIG"} );
	}
	else {
		$clconf{"CONFIG"} = readPropertyFile( "DocumentAlignment.prop" );
	}

	return \%clconf;
}

sub readPropertyFile( $ ) {
	my( %propHash ) = ();
	
	open( INFILE, "<", $_[0] ) or die( "DocumentAlignment::readPropertyFile: cannot open file '$_[0]' !\n" );
	binmode( INFILE, ":utf8" );
	
	while ( my $line = <INFILE> ) {
		$line =~ s/^\x{FEFF}//; # cuts BOM
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		
		if ( $line ne "" && $line !~ /^\s*#/ ) {
			my( $key, $value ) = split( /=/, $line, 2 );
			
			$key =~ s/^\s+//;
			$key =~ s/\s+$//;
			$value =~ s/^\s+//;
			$value =~ s/\s+$//;
		
			if ( defined( $key ) && defined( $value ) ) {
				$propHash{$key} = $value;
			}
		}
	}
	
	close INFILE;
	
	return \%propHash;
}

sub normalizeLang( $ ) {
	my( $lang ) = lc( $_[0] );
	my( %accuratlanguages ) = (
		#1
		"romanian" => "ro",
		"rum" => "ro",
		"ron" => "ro",
		"ro" => "ro",
		#2
		"english" => "en",
		"eng" => "en",
		"en" => "en",
		#3
		"estonian" => "et",
		"est" => "et",
		"et" => "et",
		#4
		"german" => "de",
		"ger" => "de",
		"deu" => "de",
		"de" => "de",
		#5
		"greek" => "el",
		"gre" => "el",
		"ell" => "el",
		"el" => "el",
		#6
		"croatian" => "hr",
		"hrv" => "hr",
		"hr" => "hr",
		#7
		"latvian" => "lv",
		"lav" => "lv",
		"lv" => "lv",
		#8
		"lithuanian" => "lt",
		"lit" => "lt",
		"lt" => "lt",
		#9
		"slovenian" => "sl",
		"slovene" => "sl",
		"slv" => "sl",
		"sl" => "sl"
	);

	return $accuratlanguages{$lang} if ( exists( $accuratlanguages{$lang} ) );
	die( "DocumentAlignment::normalizeLang: unknown language '$lang' !\n" );
}

sub getFullLanguageName( $ ) {
	my( $lang ) = lc( $_[0] );
	my( %accuratlanguages ) = (
		#1
		"ro" => "Romanian",
		#2
		"en" => "English",
		#3
		"et" => "Estonian",
		#4
		"de" => "German",
		#5
		"el" => "Greek",
		#6
		"hr" => "Croatian",
		#7
		"lv" => "Latvian",
		#8
		"lt" => "Lithuanian",
		#9
		"sl" => "Slovene"
	);

	return $accuratlanguages{$lang} if ( exists( $accuratlanguages{$lang} ) );
	die( "DocumentAlignment::getFullLanguageName: unknown language '$lang' !\n" );
}

sub swapDocumentAlignments( $ ) {
	my( @swappedalignments ) = ();
	
	open( DOCAL, "<", $_[0] ) or die( "DocumentAlignment::swapDocumentAlignments: cannot open file '$_[0]' for reading !\n" );
	binmode( DOCAL, ":utf8" );
	
	while ( my $line = <DOCAL> ) {
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		
		my( $srcdoc, $trgdoc, $score ) = split( /\t+/, $line );
		
		push( @swappedalignments, $trgdoc . "\t" . $srcdoc . "\t" . $score . "\n" );
	}
	
	close( DOCAL );
	
	open( DOCAL, ">", $_[0] ) or die( "DocumentAlignment::swapDocumentAlignments: cannot open file '$_[0]' for writing !\n" );
	binmode( DOCAL, ":utf8" );
	
	foreach my $al ( @swappedalignments ) {
		print( DOCAL $al );
	}
	
	close( DOCAL );
}

sub absolutePathDocuments( $ ) {
	open( DOCL, "<", $_[0] ) or die( "DocumentAlignment::absolutePathDocuments: cannot open file '$_[0]' !\n" );
	binmode( DOCL, ":utf8" );
	
	while ( my $line = <DOCL> ) {
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		
		return 0 if ( $line !~ /^[A-Z]:\\/ );
	}
	
	close( DOCL );
	return 1;
}
