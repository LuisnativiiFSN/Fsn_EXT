controladdin "SPLN Demo"
{
    HorizontalStretch = true;
    VerticalStretch = true;
    RequestedWidth = 900;
    RequestedHeight = 650;
    VerticalShrink = false;
    HorizontalShrink = true;

    Images = 'src/Image/Callback.html';
    Scripts = 'src/JsScript/WebPageViewerHelper.js', 'src/JsScript/WebPageViewer.js';
    StyleSheets = 'src/Stylesheet/Style.css';

    procedure Navigate(url: Text);
    procedure Navigate(url: Text; method: Text; data: Text);
    procedure InitializeIFrame(ratio: Text);
    procedure SetContent(html: Text);
    procedure SetContent(html: Text; javaScript: Text);
    procedure PostMessage(message: Text; targetOrigin: Text; convertToJson: Boolean);
    procedure LinksOpenInNewWindow();
    procedure InvokeEvent(data: Text);
    procedure SubscribeToEvent(eventName: Text; origin: Text);
    event ControlAddInReady(callbackUrl: Text);
    event Refresh(callbackUrl: Text);
    event DocumentReady();
    event ProductosRecibidos(array: JsonObject);
    event HistoricoVenta(array: JsonObject);
    event CrearCliente(array: JsonObject);
    event RecibirDatos(array: JsonObject);
    event Callback(data: Text);
}