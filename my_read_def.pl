#!/usr/bin/perl

# Description : Takes input coordinates (x,y) and target metal layer (met)
# 			    Reports which nets exist on a given layer at given location
#				
# Author	  : Md. Mahmudul Hassan
#
# TODO 		  : 1) Read routing widths from LEF
#				2) Include SPECIALNETS,FILLS


use Data::Dumper;

##########################   INPUTS  ################################
my $pst_def_file ="nets_only.def";
my %pst_metal_widths = (
	'M1'=>70,'M2'=>70,'M3'=>70,'M4'=>70,'M5'=>70,'M6'=>70,'M7'=>70,'M8'=>70,'M9'=>400,
);
my @pst_input = qw(5670 4130 M2);

######################################################################

my $pst_file_h;
my @pst_keywords = ("NETS");
my %pst_vias;

open($pst_file_h,'<',$pst_def_file);


while (<$pst_file_h>) {
	if (/^\s*VIAS/){
		read_vias(\$pst_file_h,\%pst_vias);	
	}
	if ( /^\s*NETS/){	
		read_nets(\$pst_file_h);	
	}		

}
#print Dumper(\%pst_vias);

#print in_rect(@rect,@pt);

sub in_rect {	
	return ($_[4]>=$_[0] && $_[4]<=$_[2] && $_[5] >= $_[1] && $_[5] <= $_[3])? 1 : 0;	
}

sub read_vias{
	my $pst_file_h = shift;	
	my $pst_vias = shift;			

	while((my $line = readline($$pst_file_h)) !~ /^\s*END\s+VIAS/){

		if($line =~ /^\s*-\s+([\S]+)/){
			my $pst_via_name = $1;
			chomp $line;
			my $statement = $line;				
			do{
				$line = readline($$pst_file_h);
				chomp $line;
				$statement .= $line;					
			}
			while($line !~ /;/);

			my @parts = split(/\+/,$statement);
			foreach $val (@parts){
				$val =~ s/\(|\)|\;|RECT//g;
				$val =~ s/^\s+//g;
				$val =~ s/\s+/ /g;					
				if($val =~ /^\s*M/){	
					$val =~ s/^\s*//g;					
					my @pst_arr = split(/\s+/,$val);
					shift @pst_arr;
					$pst_vias->{$pst_via_name} = \@pst_arr;
				}
			}
		}	
	}

}

sub parse_points{
	my $string = $_[0];
	my @pst_rect;

	$string =~ s/MASK\s+\d+//ig;
	$string =~ /\s+(M\d+)/;

	my $pst_metal_width = $pst_metal_widths{$1};	

	#NEW  M3 ( 34000 4480 0 ) ( 34390 * 0 )	
	if($string =~ /(?<x1>\d+)\s+(?<y1>\d+)\s+(?<ex1>\d+)?.*?(?<x2>[\d|\*]+)\s+(?<y2>[\d|\*]+)\s+(?<ex2>[\d|\*]+)?/){

		#print Dumper(\%+);return;
		my $ex1 = $+{ex1};
		$ex1 = defined $ex1 ? $ex1 : $pst_metal_width/2;
		my $ex2 = $+{ex2};
		$ex2 = defined $ex2 ? $ex2 : $pst_metal_width/2;

		$x1 = $+{x1};
		$y1 = $+{y1};
		
		$x2 = $+{x2}=="*"? $x1:$+{x2};
		$y2 = $+{y2}=="*"? $y1:$+{y2};

		if($y1==$y2){
			$pst_rect[0] = $x1-$ex1;
			$pst_rect[2] = $x2+$ex2;
			$pst_rect[1] = $y1-$pst_metal_width/2;
			$pst_rect[3] = $y2+$pst_metal_width/2;
		}
		elsif($x1 == $x2){
			$pst_rect[0] = $x1-$pst_metal_width/2;
			$pst_rect[2] = $x2+$pst_metal_width/2;
			$pst_rect[1] = $y1-$ex1;
			$pst_rect[3] = $y2+$ex2;
		}
		$pst_rect[4] = "NET";
		
	}	
	elsif($string =~ /(?<x1>\d+)\s+(?<y1>\d+).*?(?<via>\S*VIA\S*)/i){

		$x1 = $+{x1};
		$y1 = $+{y1};
		$via = $+{via};

		# my @pst_origin = $pst_vias{$via};
		
		# print $pst_vias{$via}[0];exit;


		$pst_rect[0] = $x1+$pst_vias{$via}[0];
		$pst_rect[2] = $x1+$pst_vias{$via}[2];
		$pst_rect[1] = $y1+$pst_vias{$via}[1];
		$pst_rect[3] = $y1+$pst_vias{$via}[3];
		$pst_rect[4] = "VIA OVERHANG";
		
	}	
	return @pst_rect;

}

sub read_nets{
	my $pst_file_h = shift;			
	
		my $pst_net_name;	
		my $pst_net_type;
		my @pst_net_endpoints;

		while((my $line = readline($$pst_file_h)) !~ /^\s*END\s+NETS/){			

			if($line =~ /^\s*\-\s+(\S+)/){				
				$pst_net_name = $1;
			}

			
			if($pst_net_name){
				#signal type
				if($line =~ /USE\s(\S+)/){
					$pst_net_type = $1;
				}			

				#endpoints	
				if($line =~ /^\s*\((.*?)\)\s*$/){					
					push(@pst_net_endpoints,$1);					
				}

				#M1 ( 25690 1830 0 ) ( 25825 * 0 )
				if($line =~ /\s+(M\d+)/){					
					my $pst_metal = $1;
					my @pst_rect = parse_points($line);	
					my $comment = pop(@pst_rect);
					if(@pst_rect){						
						if(in_rect(@pst_rect,$pst_input[0],$pst_input[1]) && $pst_metal eq $pst_input[2]){
							print "\n\nMatches for point ($pst_input[0],$pst_input[1]) in $pst_metal :\n";
							printf "%-30s: %-10s\n","Net Name",$pst_net_name;
							printf "%-30s: %-10s\n","Net Type",$pst_net_type;
							printf "%-30s: %-10s\n","DEF Line No",$.;
							printf "%-30s: %-10s\n","End Points","@pst_net_endpoints";
							printf "%-30s: %-10s\n","Comment","$comment";
						}
						
					}
				}

			}
			if($line =~ /;/){
				$pst_net_name = "";
				$pst_net_type ="";
				undef @pst_net_endpoints;
			}												

		}	
}