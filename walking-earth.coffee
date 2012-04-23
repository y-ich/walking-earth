# Street View KML generator
# author: ICHIKAWA, Yuji (New 3 Rs)
# License: MIT
# Copyright (C) 2012 ICHIKAWA, Yuji (New 3 Rs)

# variables

map = null
odd = true
limit = 200
ge = null
geocoder = null

#functions

directionsStatuses = (key for key, value in google.maps.DirectionsStatus)

start_marker = (latLng) ->
    if start_marker.marker?
        start_marker.marker.setPosition latLng
    else
        start_marker.marker = new google.maps.Marker
            position : latLng
            map : map

end_marker = (latLng) ->
    if end_marker.marker?
        end_marker.marker.setPosition latLng
    else
        end_marker.marker = new google.maps.Marker
            position : latLng
            map : map


getStreetViewPath = (path, callback) ->
    result = []
    streetViewService = new google.maps.StreetViewService()
    $('#progress').text '**********'

    repeatLatLng = (i) ->
        streetViewService.getPanoramaByLocation path[i], 49, ((n) -> # 49 (less than 50) is a magic number to get nearest location.
                (data, status) ->
                    if status is google.maps.StreetViewStatus.OK
                        result.push data.location.latLng unless data.location.latLng.equals result[result.length - 1]
                        if n + 1 < path.length
                            ratio = Math.floor 10 * (n + 1) / path.length
                            $('#progress').text '..........'.slice(0, ratio) + '**********'.slice(0, 10 - ratio)
                            repeatLatLng(n + 1)
                        else
                            $('#progress').text ''
                            callback result
                            line = new google.maps.Polyline
                                map : map
                                path : result
                                strokeColor : 'red'
                    else
                        alert "getPanoramaByLocation: " + status
            )(i)

    repeatLatLng(0)


generateKMLFromPath = (path, speed) ->
    params = []
    distance = null

    for i in [0...path.length - 1]
        params.push
                lat : path[i].lat()
                lng : path[i].lng()
                heading : bearingBetween path[i], path[i + 1]
                duration : if distance? then distance / speed else 0 # the last computation
        distance = google.maps.geometry.spherical.computeDistanceBetween path[i], path[i + 1]

    params.push
                lat : path[path.length - 1].lat()
                lng : path[path.length - 1].lng()
                heading : if path.length is 1 then 0 else bearingBetween path[path.length - 2], path[path.length - 1]
                duration : if distance? then distance / speed else 0

    generateKMLFromParams params


generateKMLFromParams = (parameters) ->
    result =
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <kml xmlns="http://www.opengis.net/kml/2.2" xmlns:gx="http://www.google.com/kml/ext/2.2">

        <gx:Tour>
          <name>your tour</name>
          <gx:Playlist>

        """
    previous = 0
    for parameter in parameters
        result +=
            """
            <gx:FlyTo>
              <gx:duration>#{parameter.duration}</gx:duration>
              #{if Math.abs(parameter.heading - previous) < 15 then "<gx:flyToMode>smooth</gx:flyToMode>" else ""}
              <Camera>
                <gx:ViewerOptions>
                  <gx:option name="streetview" enabled="1" />
                </gx:ViewerOptions>
                <gx:horizFov>85</gx:horizFov>
                <altitude>2.5</altitude>
                <longitude>#{parameter.lng}</longitude>
                <latitude>#{parameter.lat}</latitude>
                <heading>#{parameter.heading}</heading>
                <tilt>90</tilt>
              </Camera>
            </gx:FlyTo>

            """
        previous = parameter.heading

    result +=
        """
            </gx:Playlist>
          </gx:Tour>
        </kml>

        """


pathOf = (route) ->
    result = []
    for leg in route.legs
        for step in leg.steps
            result = result.concat step.path
    result


# process a route by callback
getRouteBetween = (origin, destination, callback) ->
    directionsService = new google.maps.DirectionsService()
    request =
        origin: origin
        destination: destination
        travelMode: google.maps.DirectionsTravelMode.WALKING 

    directionsService.route request, (result, status) ->
        if status is google.maps.DirectionsStatus.OK
            callback result.routes[0]
        else
            alert 'DirectionService: ' + status


bearingBetween = (origin, destination) ->
    return Number.NaN if origin.equals(destination)

    lat1 = origin.lat().toRad();
    lat2 = destination.lat().toRad();
    dLon = (destination.lng() - origin.lng()).toRad();

    y = Math.sin(dLon)*Math.cos(lat2);
    x = Math.cos(lat1)*Math.sin(lat2) - Math.sin(lat1)*Math.cos(lat2)*Math.cos(dLon);
    Math.atan2(y, x).toBrng();


Number.prototype.toRad = ->
    this*Math.PI/180

Number.prototype.toDeg = ->
    this*180/Math.PI

Number.prototype.toBrng = ->
    (this.toDeg() + 360)%360


#initialize
window.onload = ->

    geocoder = new google.maps.Geocoder()
    latlng = new google.maps.LatLng 35.757794, 139.876819

    myOptions =
        zoom: 16,
        center: latlng,
        mapTypeId: google.maps.MapTypeId.ROADMAP

    map = new google.maps.Map document.getElementById("map_canvas"), myOptions

    google.maps.event.addListener map, 'click', (event) ->
        if odd
            start_marker event.latLng
            $('#origin').val event.latLng.lat().toString() + ',' + event.latLng.lng().toString()
        else
            end_marker event.latLng
            $('#destination').val event.latLng.lat().toString() + ',' + event.latLng.lng().toString()
        odd = not odd

    $('#route').bind 'click', ->
        return unless start_marker.marker? and end_marker.marker?

        getRouteBetween start_marker.marker.getPosition(), end_marker.marker.getPosition(), (route) ->
            p = pathOf route
            line = new google.maps.Polyline
                map : map
                path : p
                strokeColor : 'blue'
            if p.length < limit
                getStreetViewPath p, (path) ->
                    kml = generateKMLFromPath path, parseFloat($('#speed').val())*1000/60/60
                    $('#kml').val kml
                    ge.getTourPlayer().setTour ge.parseKml kml
                    ge.getTourPlayer().play()
            else
                alert "It seems too long path(#{p.length}). Please try shorter one."

    $('#address').bind 'change', ->
        console.log 'pass'
        geocoder.geocode {address : this.value }, (result, status) ->
            if status is google.maps.GeocoderStatus.OK
                map.setCenter result[0].geometry.location
            else
                alert status


google.setOnLoadCallback ->
    google.earth.createInstance 'map3d', (instance) ->
            ge = instance
            ge.getWindow().setVisibility true
        , ->
