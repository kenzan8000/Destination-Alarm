/// MARK: - DAGMSMapView
class DAGMSMapView: GMSMapView {

    /// MARK: - properties

    static let sharedInstance = DAGMSMapView()

    /// editing point
    var editingPoint: CLLocationCoordinate2D?
    /// editing marker
    var editingMarker: GMSMarker?

    /// waypoints for routing
    var waypoints: [CLLocationCoordinate2D] = []
    /// destination
    var destination: CLLocationCoordinate2D?

    /// route json
    private var routeJSON: JSON?
    /// crimes
    private var crimes: [DACrime]?
    /// crime marker type
    private var crimeMarkerType = DAVisualization.None


    /// MARK: - public api

    /**
     * draw all markers, route, overlays and something like that
     **/
    func draw() {
        self.clear()

        // crime
        if self.crimes != nil {
            switch (self.crimeMarkerType) {
                case DAVisualization.CrimePoint:
                    self.drawCrimeMakers()
                    break
                case DAVisualization.CrimeHeatmap:
                    self.drawCrimeHeatmap()
                    break
                default:
                    break
            }
        }

        // route
        if self.routeJSON != nil { self.drawRoute() }
    }

    /**
     * set route json
     * @param json json
     **/
    func setRouteJSON(json: JSON?) {
        self.routeJSON = json
        if json == nil { self.removeAllPoints() }

        let locations = self.endLocations()
        let index = locations.count - 1
        if index >= 0 {
            self.destination = locations[index]
        }
    }

    /**
     * set crime marker type
     * @param markerType DAVisualization
     **/
    func setCrimeMarkerType(markerType: DAVisualization) {
        self.crimeMarkerType = markerType
    }

    /**
     * set crimes
     * @param crimes [DACrime]
     **/
    func setCrimes(crimes: [DACrime]?) {
        self.crimes = crimes
        if self.crimes == nil { self.crimeMarkerType = DAVisualization.None }
        else if self.crimes!.count == 0 { self.crimeMarkerType = DAVisualization.None }
    }

    /**
     * get minimum coordinate
     * @return CLLocationCoordinate2D
     **/
    func getMinimumCoordinate() -> CLLocationCoordinate2D {
        var min = self.projection.coordinateForPoint(CGPointMake(0, 0))
        let points = [
            CGPointMake(0, self.frame.size.height),
            CGPointMake(self.frame.size.width, 0),
            CGPointMake(self.frame.size.width, self.frame.size.height),
        ]
        for point in points {
            let coordinate = self.projection.coordinateForPoint(point)
            if min.latitude > coordinate.latitude { min.latitude = coordinate.latitude }
            if min.longitude > coordinate.longitude { min.longitude = coordinate.longitude }
        }
        return min
    }

    /**
     * get maximum coordinate
     * @return CLLocationCoordinate2D
     **/
    func getMaximumCoordinate() -> CLLocationCoordinate2D {
        var max = self.projection.coordinateForPoint(CGPointMake(0, 0))
        let points = [
            CGPointMake(0, self.frame.size.height),
            CGPointMake(self.frame.size.width, 0),
            CGPointMake(self.frame.size.width, self.frame.size.height),
        ]
        for point in points {
            let coordinate = self.projection.coordinateForPoint(point)
            if max.latitude < coordinate.latitude { max.latitude = coordinate.latitude }
            if max.longitude < coordinate.longitude { max.longitude = coordinate.longitude }
        }
        return max
    }


    /**
     * add point for routing
     * @param point(destination or waypoint) CLLocationCoordinate2D
     */
    func appendPoint(point: CLLocationCoordinate2D) {
        if self.destination == nil {
            self.destination = point
        }
        else {
            self.waypoints.append(point)
        }
    }

    /**
     * remove all points for routing
     */
    func removeAllPoints() {
        self.destination = nil
        self.waypoints = []
    }

    /**
     * delete editing marker
     **/
    func deleteEditingMarker() {
        if self.editingMarker == nil { return }

        // destination
        if self.editingMarker!.isKindOfClass(DADestinationMarker) {
        }
        // waypoint
        else if self.editingMarker!.isKindOfClass(DAWaypointMarker) {
        }

        self.editingMarker!.map = nil
        self.editingMarker = nil
    }

    /**
     * startMovingWaypoint
     * @param waypoint waypoint
     */
    func startMovingWaypoint(waypoint: CLLocationCoordinate2D) {
        self.editingPoint = waypoint
    }

    /**
     * endMovingWaypoint
     * @param waypoint waypoint
     */
    func endMovingWaypoint(waypoint: CLLocationCoordinate2D) {
        if self.editingPoint == nil { return }

        let index = self.waypointIndex(waypoint: self.editingPoint!)
        self.editingPoint = nil
        if index != nil { self.waypoints[index!] = waypoint }
    }

    /**
     * is editing now?
     * @return BOOL
     **/
    func isEditingNow() -> Bool {
        return (self.editingPoint != nil)
    }


    /// MARK: - private api

    /**
     * draw route
     **/
    private func drawRoute() {
        let pathes = self.encodedPathes()
        for pathString in pathes {
            let path = GMSPath(fromEncodedPath: pathString)
            var line = GMSPolyline(path: path)
            line.strokeWidth = 4.0
            line.tappable = false
            line.strokeColor = UIColor(red: CGFloat(35.0/255.0), green: CGFloat(150.0/255.0), blue: CGFloat(232.0/255.0), alpha: 1.0)
            line.map = self
            line.zIndex = DAGoogleMap.ZIndex.Route
        }

        if self.destination != nil {
            self.drawDestination(location: self.destination!)
        }

        self.drawWaypoints()
    }

    /**
     * draw waypoint
     **/
    private func drawWaypoints() {
        for var i = 0; i < self.waypoints.count; i++ {
            var waypoint = self.waypoints[i]
            self.drawWaypoint(location: waypoint)
        }
    }

    /**
     * draw waypoint marker
     * @param location location
     **/
    private func drawWaypoint(#location: CLLocationCoordinate2D) {
        var marker = DAWaypointMarker(position: location)
        marker.map = self
        marker.zIndex = DAGoogleMap.ZIndex.Waypoint
    }

    /**
     * draw destination marker
     * @param location location
     **/
    private func drawDestination(#location: CLLocationCoordinate2D) {
        var marker = DADestinationMarker(position: location)
        marker.map = self
        marker.zIndex = DAGoogleMap.ZIndex.Destination
    }

    /**
     * draw crimes
     **/
    private func drawCrimeMakers() {
        if self.crimes == nil { return }
        let drawingCrimes = self.crimes as [DACrime]!
        for crime in drawingCrimes {
            self.drawCrimeMaker(crime)
        }
    }

    /**
     * draw crime marker
     * @param crime DACrime
     **/
    private func drawCrimeMaker(crime: DACrime) {
        var marker = DACrimeMarker(position: CLLocationCoordinate2DMake(crime.lat.doubleValue, crime.long.doubleValue), crime: crime)
        marker.map = self
        marker.zIndex = DAGoogleMap.ZIndex.Icon
    }

    /**
     * draw crime heatmap
     **/
    private func drawCrimeHeatmap() {
        if self.crimes == nil { return }

        let drawingCrimes = self.crimes as [DACrime]!
        if drawingCrimes.count == 0 { return }

        let overlay = GMSGroundOverlay(
            position: self.projection.coordinateForPoint(CGPointMake(self.frame.size.width / 2.0, self.frame.size.height / 2.0)),
            icon: UIImage.heatmapImage(map: self, crimes: drawingCrimes),
            zoomLevel: CGFloat(self.camera.zoom)
        )
        overlay.bearing = self.camera.bearing
        overlay.map = self
        overlay.zIndex = DAGoogleMap.ZIndex.Heatmap
    }

    /**
     * return encodedPath
     * @return [String]
     **/
    private func encodedPathes() -> [String] {
        // make pathes
        var pathes = [] as [String]
        let json = self.routeJSON
        if json == nil { return pathes }

        let routes = json!["routes"].arrayValue
        for route in routes {
            let overviewPolyline = route["overview_polyline"].dictionaryValue
            let path = overviewPolyline["points"]!.stringValue
            pathes.append(path)
        }

        return pathes
    }

    /**
     * return end location
     * @return [CLLocationCoordinate2D]
     **/
    private func endLocations() -> [CLLocationCoordinate2D] {
        var locations: [CLLocationCoordinate2D] = []
        let json = self.routeJSON
        if json == nil { return locations }

        let routes = json!["routes"].arrayValue
        for route in routes {
            let legs = route["legs"].arrayValue
            for leg in legs {
                if let locationDictionary = leg["end_location"].dictionary {
                    locations.append(CLLocationCoordinate2D(latitude: locationDictionary["lat"]!.doubleValue, longitude: locationDictionary["lng"]!.doubleValue))
                }
            }
        }
        return locations
    }

    /**
     * return waypoints index from location
     * @param waypoint CLLocationCoordinate2D
     * @return Int or nil
     **/
    private func waypointIndex(#waypoint: CLLocationCoordinate2D) -> Int? {
        var index = -1
        for var i = 0; i < self.waypoints.count; i++ {
            let location1 = CLLocation(latitude: self.waypoints[i].latitude, longitude: self.waypoints[i].longitude)
            let location2 = CLLocation(latitude: waypoint.latitude, longitude: waypoint.longitude)
            let meter = location1.distanceFromLocation(location2)
            if meter > 10 { continue }
            index = i
            break
        }
        return (index >= 0) ? index : nil
    }

}
