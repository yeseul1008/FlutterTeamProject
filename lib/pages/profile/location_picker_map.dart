import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class LocationPickerMap extends StatefulWidget {
  final Function(GeoPoint, String) onLocationSelected;

  const LocationPickerMap({super.key, required this.onLocationSelected});

  @override
  State<LocationPickerMap> createState() => _LocationPickerMapState();
}

class _LocationPickerMapState extends State<LocationPickerMap> {
  GoogleMapController? _mapController;
  LatLng _selectedPosition = LatLng(37.4563, 126.7052);
  final TextEditingController _locationNameController = TextEditingController();
  bool _isSearching = false;

  Future<void> _searchLocation(String address) async {
    if (address.trim().isEmpty) return;

    setState(() {
      _isSearching = true;
    });

    try {
      List<Location> locations = await locationFromAddress(address);

      if (locations.isNotEmpty) {
        final location = locations.first;
        final newPosition = LatLng(location.latitude, location.longitude);

        setState(() {
          _selectedPosition = newPosition;
        });

        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(newPosition, 15),
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('위치를 찾았습니다!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('위치를 찾을 수 없습니다')),
        );
      }
    } catch (e) {
      print('Error searching location: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('위치 검색 실패')),
      );
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  @override
  void dispose() {
    _locationNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Location name input with autocomplete
        GooglePlaceAutoCompleteTextField(
          textEditingController: _locationNameController,
          googleAPIKey: dotenv.env['GOOGLEMAP_API_KEY']!,// "YOUR_API_KEY_HERE", // Replace with your API key
          inputDecoration: InputDecoration(
            hintText: '위치 이름 입력 (예: 서울역)',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            suffixIcon: IconButton(
              icon: Icon(Icons.search),
              onPressed: () => _searchLocation(_locationNameController.text),
            ),
          ),
          debounceTime: 400,
          countries: ["kr"],
          isLatLngRequired: true,
          getPlaceDetailWithLatLng: (Prediction prediction) {
            if (prediction.lat != null && prediction.lng != null) {
              final newPosition = LatLng(
                double.parse(prediction.lat!),
                double.parse(prediction.lng!),
              );

              setState(() {
                _selectedPosition = newPosition;
              });

              _mapController?.animateCamera(
                CameraUpdate.newLatLngZoom(newPosition, 15),
              );
            }
          },
          itemClick: (Prediction prediction) {
            _locationNameController.text = prediction.description ?? "";
            _locationNameController.selection = TextSelection.fromPosition(
              TextPosition(offset: prediction.description?.length ?? 0),
            );
          },
          seperatedBuilder: Divider(),
          itemBuilder: (context, index, Prediction prediction) {
            return Container(
              padding: EdgeInsets.all(10),
              child: Row(
                children: [
                  Icon(Icons.location_on, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(prediction.description ?? ""),
                  ),
                ],
              ),
            );
          },
        ),
        SizedBox(height: 10),
        // Map
        Expanded(
          child: GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _selectedPosition,
              zoom: 14,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
            },
            onTap: (position) {
              setState(() {
                _selectedPosition = position;
              });
            },
            markers: {
              Marker(
                markerId: MarkerId('selected'),
                position: _selectedPosition,
              ),
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          ),
        ),
        SizedBox(height: 10),
        // Confirm button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              final locationName = _locationNameController.text.trim();
              if (locationName.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('위치 이름을 입력해주세요')),
                );
                return;
              }

              final geoPoint = GeoPoint(
                _selectedPosition.latitude,
                _selectedPosition.longitude,
              );

              widget.onLocationSelected(geoPoint, locationName);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFCAD83B),
              foregroundColor: Colors.black,
            ),
            child: Text('확인'),
          ),
        ),
      ],
    );
  }
}