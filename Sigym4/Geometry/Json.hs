{-# OPTIONS_GHC -fno-warn-orphans #-}
{-# LANGUAGE FlexibleContexts
           , FlexibleInstances
           , ScopedTypeVariables
           , OverloadedStrings
           #-}
module Sigym4.Geometry.Json (
    jsonEncode
  , jsonDecode
  ) where

import Control.Applicative
import Data.Aeson
import Data.Text (Text, unpack)
import Data.Aeson.Types (Parser, Pair)
import Sigym4.Geometry.Types
import Data.ByteString.Lazy (ByteString)
import qualified Data.Vector as V

jsonEncode :: (VectorSpace v)
           => Geometry v -> ByteString
jsonEncode = encode

jsonDecode :: (VectorSpace v)
           => ByteString -> Either String (Geometry v)
jsonDecode = eitherDecode

instance VectorSpace v => ToJSON (Geometry v) where
    toJSON (GeoPoint g)
      = typedObject "Point"
        ["coordinates" .= pointCoordinates g]
    toJSON (GeoMultiPoint g)
      = typedObject "MultiPoint"
        ["coordinates" .= V.map pointCoordinates g]
    toJSON (GeoLineString g)
      = typedObject "LineString"
        ["coordinates" .= lineStringCoordinates g]
    toJSON (GeoMultiLineString g)
      = typedObject "MultiLineString"
        ["coordinates" .= V.map lineStringCoordinates g]
    toJSON (GeoPolygon g)
      = typedObject "Polygon"
        ["coordinates" .= polygonCoordinates g]
    toJSON (GeoMultiPolygon g)
      = typedObject "MultiPolygon"
        ["coordinates" .= V.map polygonCoordinates g]
    toJSON (GeoCollection g)
      = typedObject "GeometryCollection"
        ["geometries" .= g]
    {-# SPECIALIZE INLINE toJSON :: Geometry V2 -> Value #-}
    {-# SPECIALIZE INLINE toJSON :: Geometry V3 -> Value #-}

parsePoint :: VectorSpace v => [Double] -> Parser (Point v)
parsePoint = maybe (fail "parsePoint: wrong dimension") (return . Point) . fromList

parsePoints :: VectorSpace v => [[Double]] -> Parser (V.Vector (Point v))
parsePoints = V.mapM parsePoint . V.fromList

parseLineString :: VectorSpace v => [[Double]] -> Parser (LineString v)
parseLineString ps = do
    points <- mapM parsePoint ps
    case mkLineString points of
        Just ls -> return ls
        Nothing -> fail "parseLineString: Invalid linestring"

parseLinearRing :: VectorSpace v => [[Double]] -> Parser (LinearRing v)
parseLinearRing ps = do
    points <- mapM parsePoint ps
    case mkLinearRing points of
        Just ls -> return ls
        Nothing -> fail "parseLinearRing: Invalid linear ring"


parsePolygon :: VectorSpace v => [[[Double]]] -> Parser (Polygon v)
parsePolygon ps = do
    rings <- V.mapM parseLinearRing (V.fromList ps)
    if V.length rings == 0
       then fail $ "parseJSON(Geometry): Polygon requires at least one linear ring"
       else return $ Polygon (V.head rings) (V.tail rings)

coords :: FromJSON a => Object -> Parser a
coords o = o .: "coordinates"

typedObject :: Text -> [Pair] -> Value
typedObject k = object . ((:) ("type" .= k))




instance VectorSpace v => FromJSON (Geometry v) where
    parseJSON (Object o) = do
        typ <- o .: "type"
        case typ of
            "Point" ->
                coords o >>= fmap GeoPoint . parsePoint :: Parser (Geometry v)
            "MultiPoint" ->
                coords o >>= fmap GeoMultiPoint . parsePoints
            "LineString" ->
                coords o >>= fmap GeoLineString . parseLineString
            "MultiLineString" ->
                coords o >>= fmap GeoMultiLineString . V.mapM parseLineString
            "Polygon" ->
                coords o >>= fmap GeoPolygon . parsePolygon
            "MultiPolygon" ->
                coords o >>= fmap GeoMultiPolygon . V.mapM parsePolygon
            "GeometryCollection" ->
                fmap GeoCollection $ o .: "geometries"
            _ -> fail $ "parseJSON(Geometry): Invalid geometry type: " ++ unpack typ
    parseJSON _ = fail "parseJSON(Geometry): Expected an object"
    {-# SPECIALIZE INLINE parseJSON :: Value -> Parser (Geometry V2) #-}
    {-# SPECIALIZE INLINE parseJSON :: Value -> Parser (Geometry V3) #-}

        

instance (ToJSON (Geometry v), ToJSON d) => ToJSON (Feature v d) where
    toJSON (Feature g ps) = typedObject "Feature" ["geometry"    .= g
                                                  , "properties" .= ps
                                                  ]
instance (FromJSON (Geometry v), FromJSON d) => FromJSON (Feature v d)
  where
    parseJSON (Object o) = Feature <$> o.: "geometry" <*> o.:"properties"
    parseJSON _ = fail "parseJSON(Feature): Expected an object"


instance (ToJSON d, ToJSON (Geometry v)) => ToJSON (FeatureCollection v d)
  where
    toJSON (FeatureCollection fs)
      = typedObject "FeatureCollection" ["features" .= fs]

instance (FromJSON d, FromJSON (Geometry v)) => FromJSON (FeatureCollection v d)
  where
    parseJSON (Object o) = do
        typ <- o .:"type"
        if typ == "FeatureCollection"
            then FeatureCollection <$> o.: "features"
            else fail $ "parseJSON(FeatureCollection): type mismatch: " ++ typ
    parseJSON _ = fail "parseJSON(FeatureCollection): Expected an object"
