dotnet
{
    assembly("mscorlib")
    {
        Version = '4.0.0.0';
        Culture = 'neutral';
        PublicKeyToken = 'b77a5c561934e089';

        type("System.Math"; "Math")
        {
        }

        /* type("System.IO.File"; "File")
         {
         }*/

        type("System.Collections.Generic.Dictionary`2"; "Dictionary_Of_T_U")
        {
        }

        /*  type("System.Array"; "Array")
          {
          }

          type("System.Text.Encoding"; "Encoding")
          {
          }

          type("System.Convert"; "Convert")
          {
          }

          type("System.IO.StreamWriter"; "StreamWriter")
          {
          }

          type("System.Int32"; "Int32")
          {
          }

          type("System.Decimal"; "Decimal")
          {
          }

          type("System.Globalization.CultureInfo"; "CultureInfo")
          {
          }

          type("System.DateTime"; "DateTime")
          {
          }

          type("System.Boolean"; "Boolean")
          {
          }

          type("System.IO.StreamReader"; "StreamReader")
          {
          }

          type("System.IO.Stream"; "Stream")
          {
          }

          type("System.Text.StringBuilder"; "StringBuilder")
          {
          }*/
    }

    /* assembly("POSAddIn")
     {
         Version = '2.0.0.0';
         Culture = 'neutral';
         PublicKeyToken = '194563f11b671d8c';

         type("LSRetail.NAV.POSFunctions"; "POSFunctions")
         {
         }
     }*/

    assembly("Newtonsoft.Json")
    {
        /*Version = '4.5.0.0';
        Culture = 'neutral';
        PublicKeyToken = '30ad4fe6b2a6aeed';*/

        type("Newtonsoft.Json.Linq.JArray"; "JArray")
        {
        }

        type("Newtonsoft.Json.Linq.JObject"; "JObject")
        {
        }

        type("Newtonsoft.Json.Linq.JToken"; "JToken")
        {
        }

        type("Newtonsoft.Json.JsonConvert"; "JsonConvert")
        {
        }

        type("Newtonsoft.Json.Linq.JValue"; "JValue")
        {
        }
    }

    assembly("System.Web")
    {
        Version = '4.0.0.0';
        Culture = 'neutral';
        PublicKeyToken = 'b03f5f7f11d50a3a';

        type("System.Web.HttpUtility"; "HttpUtility")
        {
        }
    }

    assembly("System.Net.Http")
    {
        Version = '4.0.0.0';
        Culture = 'neutral';
        PublicKeyToken = 'b03f5f7f11d50a3a';

        /*type("System.Net.Http.HttpResponseMessage"; "HttpResponseMessage")
        {
        }*/

        type("System.Net.Http.HttpContent"; "HttpContent")
        {
        }

        type("System.Net.Http.HttpClient"; "HttpClient")
        {
        }

        type("System.Net.Http.Headers.AuthenticationHeaderValue"; "AuthenticationHeaderValue")
        {
        }

        type("System.Net.Http.Headers.EntityTagHeaderValue"; "EntityTagHeaderValue")
        {
        }

        type("System.Net.Http.HttpRequestMessage"; "HttpRequestMessage")
        {
        }

        type("System.Net.Http.HttpMethod"; "HttpMethod")
        {
        }

        type("System.Net.Http.StringContent"; "StringContent")
        {
        }
    }

    assembly("System")
    {
        Version = '4.0.0.0';
        Culture = 'neutral';
        PublicKeyToken = 'b77a5c561934e089';

        type("System.Uri"; "Uri")
        {
        }

        type("System.Net.ServicePointManager"; "ServicePointManager")
        {
        }

        type("System.Net.SecurityProtocolType"; "SecurityProtocolType")
        {
        }

        type("System.Net.HttpWebRequest"; "HttpWebRequest")
        {
        }

        type("System.Net.HttpWebResponse"; "HttpWebResponse")
        {
        }
    }

    assembly("System.Xml")
    {
        Version = '4.0.0.0';
        Culture = 'neutral';
        PublicKeyToken = 'b77a5c561934e089';

        type("System.Xml.XmlDocument"; "XmlDocument")
        {
        }

        type("System.Xml.XmlNodeList"; "XmlNodeList")
        {
        }

        type("System.Xml.XmlNode"; "XmlNode")
        {
        }

        type("System.Xml.XmlTextReader"; "XmlTextReader")
        {
        }

        type("System.Xml.XmlElement"; "XmlElement")
        {
        }
    }

    /*assembly("LSPinPad")
    {
        Version = '1.0.0.0';
        Culture = 'neutral';
        PublicKeyToken = 'null';

        type("LSPinPad.Master"; "Master")
        {
        }
    }*/

}
