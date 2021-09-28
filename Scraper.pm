package XML::Scraper;
{
    our $VERSION = '1.01';
    use 5.006;
    use strict;
    use warnings;

    use XML::LibXML qw(:libxml);
    use Data::Dumper::Concise qw(Dumper);
    use Digest::MD5 qw(md5_hex);

    # _createNode is recursive: limit it's call depth

    use constant (
        MAX_STACK_DEPTH => 30
    );

    sub new {
        my $self = {  };
        bless $self;
        return $self;
    }

    sub _createNode {

        my ($self, $parent, $cfg, $context, $depth) = @_;

        # sanity check stack depth TODO allow user overrides for truly heroicc datt structures?

        $depth ++;
        $depth > MAX_STACK_DEPTH && die "too deep $depth\n";

        # create a hash into which the DOM values are loaded

        my $vparent = $self->_validName($parent);
        my $src .=  ( '  ' x $depth) ."my %$vparent;\n";

        # look for query keys which contain findnodes to build hash/array sub data

        my @keys = keys %{$cfg};
        my @queryKeys  =  grep /^_/, @keys;
        my %queryKeys = map { $_ => 1 } @queryKeys;
        my %notPropertyMembers;

        #.. and process those queries

        foreach my $qk (@queryKeys) {

            # check if the target storage is an array (order is preserved)
            # or a hash, in which case expect a key:
            #     _films   :              '@movie:findnodes://movie'
            #     _films   :              '%movie:id:findnodes://movie'

            my $hashid;
            my ($arrayName,$action,$query) = split ':',  $cfg->{$qk};
            my $ishash = $arrayName =~ /^%/ ? 1 : 0;
            if ( $ishash ) {
                ($arrayName,$hashid,$action,$query) = split ':',  $cfg->{$qk};
                $arrayName =~ s/%/@/;
            }

            # get some variable names to help with code gen
            # and replace '-' with '_' in names

            my $name = $arrayName;
            $name =~ s/[@%]//;
            my $vname = $self->_validName($name);
            my $defName = $vname."Def";
            $arrayName = $self->_validName($arrayName);

            $notPropertyMembers{$qk}++;
            $notPropertyMembers{$name}++;

            # generate code to iterate over all the nodes returned by findnodes..
            # && recursive into children

            $src .= ( '  ' x $depth).     "my $arrayName". "Defs = \$".$context ."->$action(\'$query\');\n";
            $src .= ( '  ' x $depth).     "my ". $arrayName ."s;\n";
            $src .= ( '  ' x $depth).     "foreach my \$$defName ($arrayName". "Defs) {\n";
            $src.=  $self->_createNode($name,$cfg->{$name},$defName,$depth);
            $src .= ( '  ' x ($depth+1)).     "push ". $arrayName. "s, \\%". $vname. ";\n";
            $src .= ( '  ' x $depth).     "}\n";

            # If  a hash ref was requested construct a hash of hash refs
            # by the requested key fields and return a reference to that
            #
            # If an output array of hash refs was requested '@' then build it
            # and store a ref on the parent.

            if ( $ishash ) {
                my $hashName = $arrayName;
                $hashName =~ s/\@/\%/g;
                $src .= ( '  ' x $depth).     "my ". $hashName . "s;\n;";
                $src .= ( '  ' x $depth).     "foreach my \$ref (". $arrayName . "s) { \$". $name."s{\$ref->{'". $hashid."'}}=\$ref;}\n";
                $src .= ( '  ' x $depth).     "\$".$vparent."{'$name'}=\\".$hashName."s;\n";
            } else {
                $src .= ( '  ' x $depth).     "\$".$vparent."{'$name'}=\\".$arrayName."s;\n";
            }
        }

        # for those data members (not query keys and structural) build the code
        # to get their values from the DOM

        my @propertyMembers =  grep { ! exists $notPropertyMembers{$_} } @keys;
        foreach my $mem (@propertyMembers) {
            my ($action,$query) = split ':',  $cfg->{$mem}; # TODO check Xpath syntax for ':'
            if ( $action eq 'to_literal_list' ) {
                 $src .= ( '  ' x $depth). "\$$vparent"."{'$mem'} = \$". $context . "->findnodes('$query')->to_literal_list();\n";
            } else {
                $src .= ( '  ' x $depth). "\$$vparent"."{'$mem'} = \$". $context . "->$action('$query');\n";
            }
        }
        return $src;
    }

    # make names from the config useable as Perl variable names

    sub _validName {
        my ($self, $name) = @_;
        $name =~ s/-/_/g;
        return $name;
    }

    # create the parse subroutine from the config

    sub _createParser {
        my ($self, $cfg) = @_;

        # build the source code for our new anonymous function

        my $src  = "\nsub { \n";
        $src .= "    my (\$dom)  = \@_;\n";
        $src .= "    print Data::Dumper::Concise::Dumper(\$dom);\n";

        keys %{$cfg} eq 1 or die "Expecting just one top level node got ". ( join ',', keys %{$cfg});

        my ($root)= ( keys %{$cfg});
        my $name = $self->_validName($root);

        # descend down the config tree building up the function

        $src .= $self->_createNode($root,$cfg->{$root},'dom',1);

        # make sure it returns the parse result

        $src .= "    return \\%$name;\n}";
        return $src;
    }

    sub parseDOM {

        my ($self,$dom, $cfg) = @_;

        # sanity check the arguments

        ref $dom eq 'XML::LibXML::Document' or die "unexpected Document Type ".ref $dom ;

        # get a unique-ish key for the config data based on its content.

        my $md5 = Digest::MD5::md5_hex(Data::Dumper::Concise::Dumper($cfg));

        # if a specialized parser has not yet been generated for this config
        # then create one

        $self->{code_table}{$md5} //= eval $self->_createParser($cfg) ;

        # and execute it

        return $self->{code_table}{$md5}->($dom);
    }

    sub getCode {
        my $self = shift;
        return $self->{code_table};
    }
}
1;
