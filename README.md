# XML-Scraper
Perl module for scraping data out of XML via LibXML/XPath, driven by a YAML style configuration.

# VERSION

Version 1.0.1

# DEPENDENCIES

```perl
    use XML::LibXML qw(:libxml);
    use Data::Dumper::Concise qw(Dumper);
    use Digest::MD5 qw(md5_hex);
    use YAML;
    use File::Slurp; # test progam only . not the XML::Scraper package itself
```

# SYNOPSIS

```
use XML::LibXML qw(:libxml);
use XML::Scraper;

use Data::Dumper::Concise;
use File::Slurp;
use YAML;

my $config = YAML::LoadFile $config_file;
my $dom = XML::LibXML->load_xml(location => $xml_file );
my $scraper = XML::Scraper->new;
my %results;
$results{playlist} = $scraper->parseDOM($dom,$config->{playlist}); 
```

# DESCRIPTION

This module provide a simple way of scraping data from XML by way of a mini
specification language based on YAML which concisely defines:

 * XPath expression to get the required data
 * LibXML method call to extract the data
 * Where to place it in a Perl data structure

This can be a great productivity boost, maybe not so much on the short examples
we have to use in READMEl pages, but it has helped on industrial sized projects,
an example of which a client has kindly allowed to me share.

Speaking of simple examples, borrowing from Grant McLean's great LibXML
[tutorial](http://grantm.github.io/perl-libxml-by-example/basics.html#a-more-complex-example)

Grant has concocted an IMDB based playlist in XML, this will be used here to describe how to use
XML::Scraper. Here is the YAML to grab all that XML into Perl:

## YAML

```YAML
playlist :
    _films   :              '%movie:id:findnodes://movie'
    movie :
        id :                'getAttribute:id'
        title :             'findvalue:./title'
        director :          'findvalue:./director'
        release-date :      'findvalue:./release-date'
        mpaa-rating :       'findvalue:./mpaa-rating'
        running-time :      'findvalue:./running-time'
        genre:              'to_literal_list:./genre'
        _actors :           '@cast:findnodes:./cast/person'
        cast :
            name :          'getAttribute:name'
            role :          'getAttribute:role'
        _info :             '@imdb-info:findnodes:./imdb-info'
        imdb-info :
            url :           'getAttribute:url'
            synopsis :      'findvalue:./synopsis'
            score :         'findvalue:./score'
```

## XML

Some XML for reference:

```XML
<playlist>
  <movie id="tt0112384">
    <title>Apollo 13</title>
    <director>Ron Howard</director>
    <release-date>1995-06-30</release-date>
    <mpaa-rating>PG</mpaa-rating>
    <running-time>140</running-time>
    <genre>adventure</genre>
    <genre>drama</genre>
    <cast>
      <person name="Tom Hanks" role="Jim Lovell" />
      <person name="Bill Paxton" role="Fred Haise" />
      <person name="Kevin Bacon" role="Jack Swigert" />
      <person name="Gary Sinise" role="Ken Mattingly" />
      <person name="Ed Harris" role="Gene Kranz" />
    </cast>
    <imdb-info url="http://www.imdb.com/title/tt0112384/">
      <synopsis>
        NASA must devise a strategy to return Apollo 13 to Earth safely
        after the spacecraft undergoes massive internal damage putting
        the lives of the three astronauts on board in jeopardy.
      </synopsis>
      <score>7.6</score>
    </imdb-info>
  </movie>
  ...
 
</playlist>
```
## Breaking down the YAML:

`playlist :`

The top level root object in the spec.

`   _films   :              '%movie:id:findnodes://movie'`

The leading underscore indicates a query field rather than part of the output Perl.
It breaks down as: 1/ Use `$dom->findnodes("//movie");` to find all the movie objects in the XML. 
2/ Store them on the Perl 'movie' element of playlist, as hash references keyed by 'id'. The
code generated is this:
```Perl
      my(@movieDefs) = $dom->findnodes('//movie');
      my @movies;
      foreach my $movieDef (@movieDefs) {
```
`    movie :`

For each movie instance process the following sub elements, with each successive movie
item as DOM context: 

`        id :              'getAttribute:id'`

Fetch attribute 'id', store on the Perl movie definition

`        title :             'findvalue:./title'`

`        director :          'findvalue:./director'`

`        release-date :      'findvalue:./release-date'`

`        mpaa-rating :       'findvalue:./mpaa-rating'`

`        running-time :      'findvalue:./running-time'`

For all the above fetch via findValue , store in Perl movie hash

`        genre:              'to_literal_list:./genre'`

Find all the genre items, store in Perl as a list of strings. The code generated does this:

```$movie{'genre'} = $movieDef->findnodes('./genre')->to_literal_list;```
 
 Now we descend further to acquire cast data:
 
 `       _actors :           '@cast:findnodes:./cast/person'`
 
 `       cast :`

The DOM context is now each successive cast member on the movie definiiton being parsed:

`            name :          'getAttribute:name'`

`           role :          'getAttribute:role'`

As above attibute values are extracted and stored on the cast array on movie.

        _info :             '@imdb-info:findnodes:./imdb-info'
        imdb-info :
            url :           'getAttribute:url'
            synopsis :      'findvalue:./synopsis'
            score :         'findvalue:./score'
```

The YAML is much more concise than writing the native Perl to do the extraction, roughly 1:3 ration spec to code.
XML::Scraper takes that specification and actually builds the boiler plate that would otherwise be lovingly hand crafted. 

## Generateed Code

Here is the code it produces for the above spec:

```Perl
sub {
      package XML::Scraper;
      use warnings;
      use strict;
      my($dom) = @_;
      print Data::Dumper::Concise::Dumper($dom);
      my %playlist;
      my(@movieDefs) = $dom->findnodes('//movie');
      my @movies;
      foreach my $movieDef (@movieDefs) {
          my %movie;
          my(@imdb_infoDefs) = $movieDef->findnodes('./imdb-info');
          my @imdb_infos;
          foreach my $imdb_infoDef (@imdb_infoDefs) {
              my %imdb_info;
              $imdb_info{'url'} = $imdb_infoDef->getAttribute('url');
              $imdb_info{'synopsis'} = $imdb_infoDef->findvalue('./synopsis');
              $imdb_info{'score'} = $imdb_infoDef->findvalue('./score');
              push @imdb_infos, \%imdb_info;
          }
          $movie{'imdb-info'} = \@imdb_infos;
          my(@castDefs) = $movieDef->findnodes('./cast/person');
          my @casts;
          foreach my $castDef (@castDefs) {
              my %cast;
              $cast{'name'} = $castDef->getAttribute('name');
              $cast{'role'} = $castDef->getAttribute('role');
              push @casts, \%cast;
          }
          $movie{'cast'} = \@casts;
          $movie{'mpaa-rating'} = $movieDef->findvalue('./mpaa-rating');
          $movie{'title'} = $movieDef->findvalue('./title');
          $movie{'release-date'} = $movieDef->findvalue('./release-date');
          $movie{'genre'} = $movieDef->findnodes('./genre')->to_literal_list;
          $movie{'director'} = $movieDef->findvalue('./director');
          $movie{'id'} = $movieDef->getAttribute('id');
          $movie{'running-time'} = $movieDef->findvalue('./running-time');
          push @movies, \%movie;
      }
      my %movies;
      foreach my $ref (@movies) {
          $movies{$ref->{'id'}} = $ref;
      }
      $playlist{'movie'} = \%movies;
      return \%playlist;
  },
```
It may not be the slickest Perl, but it gets the job done. You never really need to see the Perl, 
unless the parse is not quite getting the data how you want it. 

## Perl Output

Here is the extracted data in Perl, coutersy of `Data::Dumper::Concise` . 

```Perl
{
  playlist => {
    movie => [
      {
        cast => [
          {
            name => "Tom Hanks",
            role => "Jim Lovell",
          },
          {
            name => "Bill Paxton",
            role => "Fred Haise",
          },
          {
            name => "Kevin Bacon",
            role => "Jack Swigert",
          },
          {
            name => "Gary Sinise",
            role => "Ken Mattingly",
          },
          {
            name => "Ed Harris",
            role => "Gene Kranz",
          },
        ],
        director => "Ron Howard",
        genre => [
          "adventure",
          "drama",
        ],
        id => "tt0112384",
        "imdb-info" => [
          {
            score => "7.6",
            synopsis => "\n        NASA must devise a strategy to return Apollo 13 to Earth safely\n        after the spacecraft undergoes massive internal damage putting\n        the lives of the three astronauts on board in jeopardy.\n      ",
            url => "http://www.imdb.com/title/tt0112384/",
          },
        ],
        "mpaa-rating" => "PG",
        "release-date" => "1995-06-30",
        "running-time" => 140,
        title => "Apollo 13",
      },
      {
        cast => [
          {
            name => "George Clooney",
            role => "Chris Kelvin",
          },
          {
            name => "Natascha McElhone",
            role => "Rheya",
          },
          {
            name => "Ulrich Tukur",
            role => "Gibarian",
          },
        ],
        director => "Steven Soderbergh",
        genre => [
          "drama",
          "mystery",
          "romance",
        ],
        id => "tt0307479",
        "imdb-info" => [
          {
            score => "6.2",
            synopsis => "\n        A troubled psychologist is sent to investigate the crew of an\n        isolated research station orbiting a bizarre planet.\n      ",
            url => "http://www.imdb.com/title/tt0307479/",
          },
        ],
        "mpaa-rating" => "PG-13",
        "release-date" => "2002-11-27",
        "running-time" => 99,
        title => "Solaris",
      },
      {
        cast => [
          {
            name => "Asa Butterfield",
            role => "Ender Wiggin",
          },
          {
            name => "Harrison Ford",
            role => "Colonel Graff",
          },
          {
            name => "Hailee Steinfeld",
            role => "Petra Arkanian",
          },
        ],
        director => "Gavin Hood",
        genre => [
          "action",
          "scifi",
        ],
        id => "tt1731141",
        "imdb-info" => [
          {
            score => "6.7",
            synopsis => "\n        Young Ender Wiggin is recruited by the International Military\n        to lead the fight against the Formics, a genocidal alien race\n        which nearly annihilated the human race in a previous invasion.\n      ",
            url => "http://www.imdb.com/title/tt1731141/",
          },
        ],
        "mpaa-rating" => "PG-13",
        "release-date" => "2013-11-01",
        "running-time" => 114,
        title => "Ender's Game",
      },
      {
        cast => [
          {
            name => "Matthew McConaughey",
            role => "Cooper",
          },
          {
            name => "Anne Hathaway",
            role => "Brand",
          },
          {
            name => "Jessica Chastain",
            role => "Murph",
          },
          {
            name => "Michael Caine",
            role => "Professor Brand",
          },
        ],
        director => "Christopher Nolan",
        genre => [
          "adventure",
          "drama",
          "scifi",
        ],
        id => "tt0816692",
        "imdb-info" => [
          {
            score => "8.6",
            synopsis => "\n        A team of explorers travel through a wormhole in space in an\n        attempt to ensure humanity's survival.\n      ",
            url => "http://www.imdb.com/title/tt0816692/",
          },
        ],
        "mpaa-rating" => "PG-13",
        "release-date" => "2014-11-07",
        "running-time" => 169,
        title => "Interstellar",
      },
      {
        cast => [
          {
            name => "Matt Damon",
            role => "Mark Watney",
          },
          {
            name => "Jessica Chastain",
            role => "Melissa Lewis",
          },
          {
            name => "Kristen Wiig",
            role => "Annie Montrose",
          },
        ],
        director => "Ridley Scott",
        genre => [
          "adventure",
          "drama",
          "scifi",
        ],
        id => "tt3659388",
        "imdb-info" => [
          {
            score => "8.1",
            synopsis => "\n        During a manned mission to Mars, Astronaut Mark Watney is\n        presumed dead after a fierce storm and left behind by his crew.\n        But Watney has survived and finds himself stranded and alone on\n        the hostile planet. With only meager supplies, he must draw upon\n        his ingenuity, wit and spirit to subsist and find a way to\n        signal to Earth that he is alive.\n      ",
            url => "http://www.imdb.com/title/tt3659388/",
          },
        ],
        "mpaa-rating" => "PG-13",
        "release-date" => "2015-10-02",
        "running-time" => 144,
        title => "The Martian",
      },
    ],
  },
```
# Public Interface

XML::Scraper has two public methods

## XML::Scraper::parseDOM
 Expects arguments:

    - DOM object of type XML::LibXML::Document
    - reference to YAML config 


Example of use:
```
use XML::LibXML qw(:libxml);
use XML::Scraper;

use Data::Dumper::Concise;
use File::Slurp;
use YAML;

my $config = YAML::LoadFile $config_file;
my $dom = XML::LibXML->load_xml(location => $xml_file );
my $scraper = XML::Scraper->new;
my %results;
$results{playlist} = $scraper->parseDOM($dom,$config); 
```
##  XML::Scraper::getCode

It pretty prints the subroutine generated for the given config. It takes a single argument:

    - reference to YAML config 

Example:
...
```
print $scraper->getCode($config);
```

# Under the Hood

The `parseDOM` method looks to see if it has already parsed the config before and created a subroutine.
A unique key is generated from MD5 checksum of the config text. So once generated it can be reused many 
times, say iterating over a bunch of XML files populated via the same schema.

Control is passed to `_createParse` which creates the bare bones of the new subroutine and then passes
control to `_createNode` which does most of the work, recursively descending through the config tree 
building the code.

# Example

See the `tests.tar.gz` tarball. `testScraper.pl` provides a full worked example
with the playlist XML and YAML described above. 

It is used to parse the XML twice, once with the movies written to Perl as an array, once as a hash
keyed on the 'id' field.

Contents:

```
tests :
    cfg/playlist.yml            The YAML config file containing the extract specs.
    expected/playlist.pl        Model text for the Perl data extract from XML.
    logs/                       timestamped log files for every test run
    Makefile                    Runs the test script via 'make' pr 'make all'
    testScraper.pl              The Perl test script itself
    tgt/                        Where the output perl 'playlist.pl' is stored
    xml/playlist.xml            The XML source data
```
# LICENSE

GGPL as described in the file LICENSE in this code repository/release/package.
