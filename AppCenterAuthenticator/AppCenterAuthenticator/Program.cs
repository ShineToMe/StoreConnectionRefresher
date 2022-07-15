using System;
using System.Windows.Forms;
using System.Text.RegularExpressions;
using Microsoft.Web.WebView2.WinForms;
using Microsoft.Web.WebView2.Core;
using System.IO;

namespace AppCenterAuthenticator
{
    internal class Program
    {
        private static bool Completed = false;
        private static WebView2 WV;

        [STAThread]
        static void Main(string[] args)
        {
            WV = new WebView2();

            Initialization();

            var form = new Form
            {
                AutoSize     = true,
                AutoSizeMode = AutoSizeMode.GrowOnly
            };

            form.Controls.Add(WV);
            form.Controls[0].Dock = DockStyle.Fill;

            form.Show();

            WV.Source = new Uri($"{Properties.Settings.Default.AuthAddressPrefix}{Properties.Settings.Default.ClientID}{Properties.Settings.Default.AuthAddressSuffix}");

            while (!Completed)
                Application.DoEvents();
        }

        private static async void Initialization()
        {
            WV.NavigationStarting += Wv_NavigationStarting;

            var options = new CoreWebView2EnvironmentOptions
            {
                AllowSingleSignOnUsingOSPrimaryAccount = true
            };

            if (string.IsNullOrEmpty(Properties.Settings.Default.BrowserPath))
            {
                var env = await CoreWebView2Environment.CreateAsync(options: options).ConfigureAwait(false);

                await WV.EnsureCoreWebView2Async(env).ConfigureAwait(false);
            }
            else
            {
                var browserPath = Path.GetFullPath(Properties.Settings.Default.BrowserPath);

                var env = await CoreWebView2Environment.CreateAsync(browserExecutableFolder: browserPath.ToString(), options: options).ConfigureAwait(false);

                await WV.EnsureCoreWebView2Async(env).ConfigureAwait(false);
            }
        }

        private static void Wv_NavigationStarting(object sender, CoreWebView2NavigationStartingEventArgs e)
        {
            if (e.Uri.ToString().Contains(Properties.Settings.Default.RedirectAddress))
            {
                e.Cancel = true;

                Console.WriteLine(Regex.Replace(e.Uri.ToString(), "(.*code=)|(&.*)", ""));

                Completed = true;
            }
        }
    }
}
