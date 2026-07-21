dotnet
{
    //Time
    assembly(mscorlib)
    {
        type(System.DateTime; MyDateTime) { }
    }

    //SQL
    assembly(System.Data)
    {
        type(System.Data.SqlClient.SqlConnection; SqlConnect) { }
        type(System.Data.SqlClient.SqlCommand; SqlCmd) { }
        type(System.Data.SqlClient.SqlDataReader; SqlDataRdr) { }
    }

    // Avengers
    /*   assembly("LSFileLog")
       {
           Version = '1.0.0.0';
           Culture = 'neutral';
           PublicKeyToken = '194563f11b671d8c';

           type("LSRetail.NAV.LSLog"; "LSCLog") { }

           type("LSRetail.NAV.LSLogLevel"; "LSCLogLevel") { }
       }


       // Avengers
       assembly("LSHardwareStationClient")
       {
           Version = '1.0.0.0';
           Culture = 'neutral';
           PublicKeyToken = '194563f11b671d8c';

           type("LSRetail.NAV.HardwareStationClient"; LSCHardwareStationClient) { }
       }

       // Omni
       assembly("LSRetail.NAV.Omni")
       {
           Version = '1.0.0.0';
           Culture = 'neutral';
           PublicKeyToken = 'null';

           type("LSRetail.NAV.Omni.Hospitality"; LSCHospitality) { }
       }

       // Navnia
       assembly("LSTools")
       {
           Version = '1.0.0.0';
           Culture = 'neutral';
           PublicKeyToken = '194563f11b671d8c';

           type("LSRetail.NAV.Utils.PrintUtil"; LSCPrintUtil) { }
           type("LSRetail.NAV.Utils.SerializationUtil"; LSCSerializationUtil) { }
           type("LSRetail.NAV.Utils.EmailUtil.SendEmail"; LSCSendEmail) { }
           type("LSRetail.NAV.Utils.NavUtil"; LSCNavUtil) { }
       }

       // ?
       assembly("LSRetail.NAV.Search")
       {
           Version = '1.0.0.0';
           Culture = 'neutral';
           PublicKeyToken = '194563f11b671d8c';

           type("LSRetail.NAV.Search.SearchEngine"; LSCSearchEngine) { }
           type("LSRetail.NAV.Search.IndexEngine"; LSCIndexEngine) { }
           type("LSRetail.NAV.Search.Helpers"; LSCHelpers) { }
           type("LSRetail.NAV.Search.Document"; LSCSearchDocument) { }
           type("LSRetail.NAV.Search.Hits"; LSCHits) { }
           type("LSRetail.NAV.Search.Hit"; LSCHit) { }
       }

       // Avengers
       assembly("LSRetail.NAV.Web.AddIn")
       {
           Version = '1.0.0.0';
           Culture = 'neutral';
           PublicKeyToken = '194563f11b671d8c';

           type("LSRetail.NAV.Web.WebPOSFunctions"; LSCWebPOSFunctions) { }
           type("LSRetail.NAV.Web.WebPosHtmlFactory"; LSCWebPosHtmlFactory) { }
           type("LSRetail.NAV.Web.POSFunctions_EventHandler"; LSCPOSFunctions_EventHandler) { }
           type("LSRetail.NAV.Web.POSFunctions"; LSCPOSFunctions) { }
       }

       // Navnia
       assembly("LSRecommend")
       {
           Version = '2.0.0.0';
           Culture = 'neutral';
           PublicKeyToken = 'null';

           type("LSRecommend.LSRecommend"; LSCRecommend) { }
       }

       // Omni
       assembly("TransAutomClient")
       {
           Version = '3.2.0.0';
           Culture = 'neutral';
           PublicKeyToken = '194563f11b671d8c';

           type("LSRetail.DD.Control.TransAutomClient"; LSCTransAutomClient) { }
       }

       // Omni
       assembly("DDConfigClient")
       {
           Version = '3.2.0.0';
           Culture = 'neutral';
           PublicKeyToken = '194563f11b671d8c';

           type("LSRetail.DD.Control.DDConfigClient"; LSCDDConfigClient) { }
       }*/

}
