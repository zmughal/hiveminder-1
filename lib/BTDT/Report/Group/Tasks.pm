use warnings;
use strict;

=head1 NAME

BTDT::Report::Group::Tasks

=head1 DESCRIPTION

Generates a report for a group's individual tasks

=cut

package BTDT::Report::Group::Tasks;
use base qw/BTDT::Report::Group/;

__PACKAGE__->mk_accessors(qw/groupings start end _dates/);

=head1 METHODS

=head2 new PARAMHASH

=cut

sub new {
    my $class = shift;
    my %args  = (
        groupings   => ['created'],
        start       => undef,
        end         => undef,
        @_
    );

    $args{'groupings'} = [$args{'groupings'}]
        if not ref $args{'groupings'};

    my $self = $class->SUPER::new(%args);

    if ( not defined $self->start and not defined $self->end ) {
        my $duration    = DateTime::Duration->new( months => 1 );
        $self->end( BTDT::DateTime->now );
        $self->start( $self->end - $duration );
    }

    return $self;
}

=head2 _get_metrics

=cut

sub _get_metrics {
    my $self = shift;
    my $GID  = $self->group->id;

    $self->start->set_time_zone('GMT');
    $self->end->set_time_zone('GMT');

    my $totals = $self->totals || {};
    my $results = $self->results || {};

    for my $grouping ( @{$self->groupings} ) {
            my $fetched = $self->count_aggregate_values_in_period(
                group_by => $grouping,
                query    => "group_id = $GID",
                start    => $self->start->ymd . " " . $self->start->hms,
                end      => $self->end->ymd . " " . $self->end->hms,
            );
            map {
                my $date = substr( $_->[0], 0, 10 );
                $totals->{$grouping} += $_->[1];
                $results->{$grouping}{$date} = $_->[1];
            } @$fetched;
    }
    $self->results($results);
    $self->totals($totals);

    $self->start->set_time_zone( $self->time_zone );
    $self->end->set_time_zone( $self->time_zone );
    $self->_get_metrics_dates;
}

=head2 _get_metrics_dates

Sets $self->_dates to an array ref of ISO8601 dates for the full period of our query

=cut

sub _get_metrics_dates {
    my $self = shift;
    my $period = DateTime::Duration->new( days => 1 );
    my @keys;
    for ( my $current = $self->start; $current <= $self->end; $current += $period) {
        push @keys, $current->ymd;
    }
    $self->_dates( \@keys );
}

=head2 labels

The first of every month uses the month's name

=cut

sub labels {
    my $self = shift;
    # substr("2007-01-23", 5, 2) eq "01"
    return map { $_ =~ /-01$/ ? DateTime->new( year => 1, month => substr($_,5,2))->month_name : '' } @{$self->_dates};
}

=head2 totals_as_array

=cut

sub totals_as_array {
    my $self    = shift;
    my $results = $self->results;

    my @data;

    for my $grouping ( @{ $self->groupings } ) {
        my %totals;
        for my $date ( @{$self->_dates} ) {
            $totals{$date} += $results->{$grouping}{$date} || 0;
        }
        push @data, [ map { defined $totals{$_} ? $totals{$_} : 0 } @{$self->_dates} ];
    }
    return @data;
}

=head2 results_as_array

=cut

sub results_as_array {
    my $self    = shift;
    my $results = $self->results;

    my @data;

    for my $grouping ( @{ $self->groupings } ) {
            push @data, [ map { my $v = $results->{$grouping}{$_}; defined $v ? $v : '0'; } @{$self->_dates} ];
    }
    return @data;
}

1;
