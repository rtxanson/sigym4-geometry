{-# OPTIONS_GHC -fno-warn-orphans #-}
{-# LANGUAGE FlexibleInstances
           , FlexibleContexts
           , ScopedTypeVariables
           , UndecidableInstances
           , CPP
           #-}
module Arbitrary where

import Test.QuickCheck
#if MIN_VERSION_base(4,8,0)
import Control.Applicative ((<$>))
#else
import Control.Applicative ((<$>), (<*>))
#endif
import Data.Maybe (fromJust)
import Data.Vector (fromList)
import Data.Proxy (Proxy(..))
import qualified Data.Vector.Unboxed as U
import qualified Data.Vector.Generic as G

import Sigym4.Geometry
import Sigym4.Geometry.QuadTree

instance {-# INCOHERENT #-} forall v. VectorSpace v
  => Arbitrary (Vertex v) where
  arbitrary = (fromVectorN . V) <$> G.replicateM n arbitrary
    where n = dim (Proxy :: Proxy v)

positiveV :: forall v. VectorSpace v => Gen (Vertex v)
positiveV = (fromVectorN . V) <$> G.replicateM n (choose (1, 1000))
  where n = dim (Proxy :: Proxy v)

instance VectorSpace v => Arbitrary (Size v) where
  arbitrary = (Size . fmap round) <$> positiveV

instance Arbitrary (Offset t) where
  arbitrary = Offset . getNonNegative <$> arbitrary

instance VectorSpace v => Arbitrary (Extent v srid) where
  arbitrary = do
    lr <- arbitrary
    d  <- positiveV
    return $ Extent lr (lr+d)

instance Arbitrary (Vertex v) => Arbitrary (Pixel v) where
  arbitrary = Pixel <$> arbitrary

instance Arbitrary (Vertex v) => Arbitrary (Point v srid) where
    arbitrary = fmap Point arbitrary

instance (VectorSpace v, Arbitrary (Vertex v))
  => Arbitrary (MultiPoint v srid) where
    arbitrary = MultiPoint <$> fmap fromList (resized arbitrary)

instance (VectorSpace v, Arbitrary (Vertex v))
  => Arbitrary (LinearRing v srid) where
    arbitrary = do ps <- (++) <$> vector 3 <*> arbitrary
                   return . fromJust . mkLinearRing $ ps ++ [head ps]

instance (VectorSpace v, Arbitrary (Vertex v))
  => Arbitrary (LineString v srid) where
    arbitrary = fmap (fromJust . mkLineString) $ (++) <$> vector 2 <*> arbitrary

instance (VectorSpace v, Arbitrary (Vertex v))
  => Arbitrary (MultiLineString v srid) where
    arbitrary = MultiLineString <$> fmap fromList (resized arbitrary)


instance (VectorSpace v, Arbitrary (Vertex v))
  => Arbitrary (Polygon v srid) where
    arbitrary = Polygon <$> arbitrary <*> fmap fromList (resized arbitrary)

instance (VectorSpace v, Arbitrary (Vertex v))
  => Arbitrary (Triangle v srid) where
    arbitrary = do
        mRet <- mkTriangle <$> arbitrary <*> arbitrary <*> arbitrary
        maybe arbitrary return mRet

instance (VectorSpace v, Arbitrary (Vertex v))
  => Arbitrary (MultiPolygon v srid) where
    arbitrary = MultiPolygon <$> fmap fromList (resized arbitrary)

instance (VectorSpace v, Arbitrary (Vertex v))
  => Arbitrary (PolyhedralSurface v srid) where
    arbitrary = PolyhedralSurface <$> fmap fromList (resized arbitrary)

instance (VectorSpace v, Arbitrary (Vertex v))
  => Arbitrary (TIN v srid) where
    arbitrary = TIN <$> fmap U.fromList (resized arbitrary)


instance (VectorSpace v, Arbitrary (Vertex v))
  => Arbitrary (Geometry v srid) where
    arbitrary = oneof (geometryCollection:geometries)
        where
            geometryCollection = GeoCollection . GeometryCollection . fromList
                             <$> (resized $ listOf (oneof geometries))
            point = GeoPoint <$> arbitrary
            lineString = GeoLineString <$> arbitrary
            polygon = GeoPolygon <$> arbitrary
            multiPolygon = GeoMultiPolygon <$> arbitrary
            multiPoint = GeoMultiPoint <$> arbitrary
            multiLineString = GeoMultiLineString <$> arbitrary
            triangle = GeoTriangle <$> arbitrary
            tin = GeoTIN <$> arbitrary
            psurface = GeoPolyhedralSurface <$> arbitrary
            geometries = [ point, lineString, polygon
                         , multiPoint, multiLineString, multiPolygon
                         , triangle, psurface, tin
                         ]

instance VectorSpace v => Arbitrary (Quadrant v) where
  arbitrary = elements [minBound..maxBound]

instance Arbitrary Level where
  arbitrary = fromInteger <$> choose (lo, hi)
    where lo = fromIntegral (unLevel minBound)
          hi = fromIntegral (unLevel maxBound)

resized :: Gen a -> Gen a
resized = resize 15