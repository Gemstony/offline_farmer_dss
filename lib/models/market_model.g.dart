// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'market_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MarketPriceAdapter extends TypeAdapter<MarketPrice> {
  @override
  final int typeId = 2;

  @override
  MarketPrice read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MarketPrice(
      cropName: fields[0] as String,
      pricePerKg: fields[1] as double,
      marketName: fields[2] as String,
      lastUpdated: fields[3] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, MarketPrice obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.cropName)
      ..writeByte(1)
      ..write(obj.pricePerKg)
      ..writeByte(2)
      ..write(obj.marketName)
      ..writeByte(3)
      ..write(obj.lastUpdated);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MarketPriceAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
