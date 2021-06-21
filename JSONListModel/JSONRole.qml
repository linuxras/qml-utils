import QtQuick 2.11
QtObject {
    id: jsonrole
    property string name
    property string query
    //JSONPath always returns and array[val] when it finds value
    //Set to true to make array[0] before what gets added to the model.
    property bool selectFirst: true
    property bool isKey: false
}
