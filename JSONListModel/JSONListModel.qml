/* JSONListModel - a QML ListModel with JSON and JSONPath support
 *
 * Copyright (c) 2012 Romain Pokrzywka (KDAB) (romain@kdab.com)
 *              modified by Andrew Williams for OpenWeatherApp 2021
 * Licensed under the MIT licence (http://opensource.org/licenses/mit-license.php)
 */

import QtQuick 2.4
import "jsonpath.js" as JSONPath

ListModel {
    id: jsonModel
    default property list<JSONRole> roles
    property string source: ""
    property string json: ""
    property string query: ""
    property int status: JSONStatus.Status.None
    property var keys: []
    //qml Normally when you specify a role with isKey: true the model will only 
    //add new records to the model that dont match current key/value.
    //This property allows you to update the properties of that record
    property bool updateKeys: false 
    property string sortBy: ""
    property var xhr: null
    property string errorString: ""
    property bool debug: false

    onSourceChanged: {
        if(debug)
            console.log("JSONListModel.onSourceChanged")
        fetch();
    }

    onJsonChanged: updateJSONModel()
    onQueryChanged: updateJSONModel()

    function fetch() {
        //if(status === JSONStatus.Status.Loading)
        //    return;
        if(xhr)
        {
         /*
          Value State Description 
          0 UNSENT Client has been created. open() not called yet. 
          1 OPENED open() has been called. 
          2 HEADERS_RECEIVED send() has been called, and headers and status are available. 
          3 LOADING Downloading; responseText holds partial data. 
          4 DONE The operation is complete. 
         */
            var s = xhr.readyState;
            switch(s) {
                case 0:
                case 1:
                case 2:
                case 3:
                    xhr.abort();
                break;
            }
        }
        if(debug)
            console.log("JSONListModel.fetch()");

        if(!xhr)
        {
            xhr = new XMLHttpRequest;
            xhr.onreadystatechange = function() {
                if (xhr.readyState == XMLHttpRequest.DONE)
                {
                    if(debug)
                        console.log("JSONListModel.fetch: Http request done HTTP", xhr.status);
                    if(xhr.status == 200)
                    {
                        json = xhr.responseText;
                    }
                    else
                    {
                        var erText = xhr.statusText;
                        if(xhr.status == 0)
                            erText = qsTr("Host not found");
                        errorString = qsTr("Failed to fetch %1 (%2): %3").arg(source).arg(erText).arg(xhr.responseText);
                        status = JSONStatus.Status.Error;
                        if(debug)
                            console.log("JSONListModel.fetch errorString:", errorString);
                    }
                }
            }
            xhr.ontimeout = function() {
                errorString = qsTr("Failed to fetch %1 : %2").arg(source).arg(qsTr("Operation timed out"))
                status = JSONStatus.Status.Error;
            }
        }
        xhr.open("GET", source);
        xhr.send();
    }

    function reload() {
        fetch();
    }
    //Overwrite clear so we can cleanup
    function clear() {
        keys = [];
        if(count)
            remove(0, count);
        status = JSONStatus.Status.None;
    }

    function updateJSONModel() {

        var skip = false, isKey = hasKey(), kName;
        status = JSONStatus.Status.Loading;
        if ( json === "" )
        {
            status = JSONStatus.Status.None;
            clear();
            return;
        }
        if(isKey)
        {
            kName = keyName();
        }
        else
        {
            clear();
        }
        //process main query
        var objectArray = parseJSONString(json, query);
        if(!objectArray)
        {
            clear();
            return;
        }
        if(debug)
            console.log("JSONListModel.updateJSONModel: Found object from JSON Query: ", objectArray.length);
        if (sortBy !== "")
            objectArray = sortByKey(objectArray, sortBy);
        for ( var key in objectArray ) {
            var jo = objectArray[key];
            if(roles && roles.length)
            {
                skip = false;
                if(debug)
                    console.log("JSONListModel.updateJSONModel: Found item for key ", key, JSON.stringify(jo));
                //Process the JSONRoles here by query so we can setup a model
                //like XmlListModel where we get known/expected data from the model
                var val = {};
                //TODO: Implement the isKey property for now we do nothing with it.
                for (var iter in roles)
                {
                    var role = roles[iter];
                    //process the query for the role
                    var obj = parseJSONString(JSON.stringify(jo), role.query, "VALUE")

                    if(obj !== false)
                    {
                        if(debug)
                            console.log("JSONListModel.updateJSONModel: Found object for role: ", role.name, role.query, JSON.stringify(obj))
                        if(role.selectFirst) {
                            val[role.name] = obj[0];
                        }
                        else {
                            val[role.name] = obj;
                        }
                        if(role.name === kName)
                        {
                            keys.push(val[role.name]);
                            if(hasKeyValue(kName, val[role.name])) {
                                skip = true;
                                if(!updateKeys)
                                {
                                    //Just stop processing here 
                                    break;
                                }
                            }
                        }
                    }
                    else
                    {
                        if(debug)
                            console.log("JSONListModel.updateJSONModel: Found no value for role : ", role.name)
                    }
                }
                if(skip)
                {
                    if(updateKeys)
                    {
                        var rv = getByKeyValue(kName, val[kName]), testObject;
                        if(rv.success)
                        {
                            if(JSON.stringify(rv.row) !== JSON.stringify(val))
                            {
                                remove(rv.index);
                                insert(rv.index, val);
                            }
                        }
                    }
                }
                else
                    append( val );
            }
            else {
                append(jo);
            }
        }
        //Clear missing rows
        if(isKey)
        {
            clearMissing(kName)
        }
        errorString = "";
        status = JSONStatus.Status.Ready;
    }

    function parseJSONString(jsonString, jsonPathQuery) {
        var objectArray = JSON.parse(jsonString);
        if ( jsonPathQuery !== "" )
            objectArray = JSONPath.jsonPath(objectArray, jsonPathQuery);

        return objectArray;
    }
    function clearMissing(keyName) {
        for(var i = count - 1; i > 0; --i)
        {
            if(keys.indexOf(get(i)[keyName]) === -1)
            {
                remove(i);
            }
        }
    }
    function hasKey() {
        var found = false;
        for (var iter in roles)
        {
            var role = roles[iter];
            if(role.isKey)
            {
                found = true;
                break;
            }
        }
        return found;
    }
    function keyName() {
        var name = "";
        for(var i in roles)
        {
            var r = roles[i];
            if(r.isKey)
            {
                name = r.name;
                break;
            }
        }
        return name;
    }
    function hasKeyValue(key, value) {
        var rval = false;
        for(var i = 0; i < count; i++)
        {
            var item = get(i);
            if(item[key] === value)
            {
                rval = true;
                break
            }
        }
        return rval;
    }
    function getByKeyValue(key, value) {
        var rv = {success: false};
        for(var i = 0; i < count; i++)
        {
            var item = get(i);
            if(item[key] === value)
            {
                rv.index = i;
                rv.row = item;
                rv.success = true;
                //rv = item;
                break
            }
        }
        return rv;
    }
    function sortByKey(array, key) {
        return array.sort(function(a, b) {
            var x = a[key]; var y = b[key];
            return ((x < y) ? -1 : ((x > y) ? 1 : 0));
        });
    }
    function errorString()
    {
        return errorString;
    }
}
