import Foundation
import CoreLocation

/**
 * A lightweight Geohash utility for Swift.
 * Provides encoding of coordinates and neighbor calculation for spatial queries.
 */
struct Geohash {
    private static let base32 = "0123456789bcdefghjkmnpqrstuvwxyz"
    private static let characterMap: [Character: Int] = {
        var map = [Character: Int]()
        for (index, char) in base32.enumerated() {
            map[char] = index
        }
        return map
    }()
    
    /**
     * Encodes a location into a Geohash string of specified precision.
     */
    static func encode(latitude: Double, longitude: Double, precision: Int = 10) -> String {
        var latRange = (-90.0, 90.0)
        var lonRange = (-180.0, 180.0)
        var geohash = ""
        var isEven = true
        var bit = 0
        var ch = 0
        
        while geohash.count < precision {
            if isEven {
                let mid = (lonRange.0 + lonRange.1) / 2
                if longitude > mid {
                    ch |= (1 << (4 - bit))
                    lonRange.0 = mid
                } else {
                    lonRange.1 = mid
                }
            } else {
                let mid = (latRange.0 + latRange.1) / 2
                if latitude > mid {
                    ch |= (1 << (4 - bit))
                    latRange.0 = mid
                } else {
                    latRange.1 = mid
                }
            }
            
            isEven.toggle()
            if bit < 4 {
                bit += 1
            } else {
                geohash.append(base32[base32.index(base32.startIndex, offsetBy: ch)])
                bit = 0
                ch = 0
            }
        }
        
        return geohash
    }
    
    /**
     * Calculates neighbors for a given geohash to cover a circular/rectangular area.
     */
    static func neighbours(for geohash: String) -> [String] {
        let latLon = decode(geohash: geohash)
        let latErr = latLon.1.latitude / 2
        let lonErr = latLon.1.longitude / 2
        
        let precision = geohash.count
        
        let n = encode(latitude: latLon.0.latitude + latErr * 2, longitude: latLon.0.longitude, precision: precision)
        let s = encode(latitude: latLon.0.latitude - latErr * 2, longitude: latLon.0.longitude, precision: precision)
        let e = encode(latitude: latLon.0.latitude, longitude: latLon.0.longitude + lonErr * 2, precision: precision)
        let w = encode(latitude: latLon.0.latitude, longitude: latLon.0.longitude - lonErr * 2, precision: precision)
        
        let ne = encode(latitude: latLon.0.latitude + latErr * 2, longitude: latLon.0.longitude + lonErr * 2, precision: precision)
        let nw = encode(latitude: latLon.0.latitude + latErr * 2, longitude: latLon.0.longitude - lonErr * 2, precision: precision)
        let se = encode(latitude: latLon.0.latitude - latErr * 2, longitude: latLon.0.longitude + lonErr * 2, precision: precision)
        let sw = encode(latitude: latLon.0.latitude - latErr * 2, longitude: latLon.0.longitude - lonErr * 2, precision: precision)
        
        return [geohash, n, s, e, w, ne, nw, se, sw]
    }
    
    /**
     * Decodes a geohash into coordinates and error margins.
     */
    private static func decode(geohash: String) -> (CLLocationCoordinate2D, (latitude: Double, longitude: Double)) {
        var latRange = (-90.0, 90.0)
        var lonRange = (-180.0, 180.0)
        var isEven = true
        
        for char in geohash {
            guard let cd = characterMap[char] else { continue }
            for mask in [16, 8, 4, 2, 1] {
                if isEven {
                    let mid = (lonRange.0 + lonRange.1) / 2
                    if (cd & mask) != 0 {
                        lonRange.0 = mid
                    } else {
                        lonRange.1 = mid
                    }
                } else {
                    let mid = (latRange.0 + latRange.1) / 2
                    if (cd & mask) != 0 {
                        latRange.0 = mid
                    } else {
                        latRange.1 = mid
                    }
                }
                isEven.toggle()
            }
        }
        
        let lat = (latRange.0 + latRange.1) / 2
        let lon = (lonRange.0 + lonRange.1) / 2
        return (CLLocationCoordinate2D(latitude: lat, longitude: lon), (latitude: latRange.1 - lat, longitude: lonRange.1 - lon))
    }
}
