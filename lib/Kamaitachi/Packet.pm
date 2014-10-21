package Kamaitachi::Packet;
use Moose;
require bytes;

use Data::AMF::IO;
use Kamaitachi::Packet::Function;

has number => (
    is  => 'rw',
    isa => 'Int',
);

has timer => (
    is      => 'rw',
    isa     => 'Int',
    lazy    => 1,
    default => sub { 0 },
);

has size => (
    is      => 'rw',
    isa     => 'Int',
    lazy    => 1,
    default => sub {
        my $self = shift;
        bytes::length($self->data);
    },
);

has type => (
    is  => 'rw',
    isa => 'Int',
);

has obj => (
    is      => 'rw',
    lazy    => 1,
    default => sub { 0 },
);

has data => (
    is  => 'rw',
    isa => 'Str',
);

has raw => (
    is  => 'rw',
    isa => 'Str',
);

has socket => (
    is       => 'rw',
    isa      => 'Object',
    weak_ref => 1,
);

has partial => (
    is      => 'rw',
    isa     => 'Int',
    lazy    => 1,
    default => sub { 0 },
);

has partial_data => (
    is      => 'rw',
    isa     => 'Str',
    lazy    => 1,
    default => sub { q[] },
);

has partial_data_length => (
    is      => 'rw',
    isa     => 'Int',
    lazy    => 1,
    default => sub {
        my $self = shift;
        bytes::length( $self->partial_data );
    },
);

no Moose;

=head1 NAME

Kamaitachi::Packet - RTMP packet

=head1 DESCRIPTION

See L<Kamaitachi>.

=head1 METHODS

=head2 serialize

=cut

sub serialize {
    my ($self, $chunk_size) = @_;
    $chunk_size ||= 128;

    my $io = Data::AMF::IO->new( data => q[] );

    if ($self->number > 255) {
        $io->write_u8( 0 & 0x3f );
        $io->write_u16( $self->number );
    }
    elsif ($self->number > 63) {
        $io->write_u8( 1 & 0x3f );
        $io->write_u8( $self->number );
    }
    else {
        $io->write_u8( $self->number & 0x3f );
    }

    $io->write_u24( $self->timer );
    $io->write_u24( $self->size );
    $io->write_u8( $self->type );
    $io->write_u32( $self->obj );

    my $size = bytes::length($self->data);

    if ($size <= $chunk_size) {
        $io->write( $self->data );
    }
    else {
        for (my $cursor = 0; $cursor < $size; $cursor += $chunk_size) {
            my $read = substr $self->data, $cursor, $chunk_size;
            $read .= pack('C', $self->number | 0xc0) if $cursor + bytes::length($read) < $size;

            $io->write( $read );
        }
    }

    $io->data;
}

=head2 function

=cut

sub function {
    my $self = shift;

    Kamaitachi::Packet::Function->new_from_packet(
        packet => $self,
        parser => $self->socket->context->parser
    );
}

=head1 AUTHOR

Daisuke Murase <typester@cpan.org>

Hideo Kimura <hide@cpan.org>

=head1 COPYRIGHT

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut

__PACKAGE__->meta->make_immutable;

