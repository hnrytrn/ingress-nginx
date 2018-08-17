/*
Copyright 2018 The Kubernetes Authors.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package lua

import (
	"fmt"
	"net/http"
	"strings"
	"time"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	"github.com/parnurzeal/gorequest"

	appsv1beta1 "k8s.io/api/apps/v1beta1"
	extensions "k8s.io/api/extensions/v1beta1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"

	"k8s.io/ingress-nginx/test/e2e/framework"
)

var _ = framework.IngressNginxDescribe("Dynamic Certificate", func() {
	f := framework.NewDefaultFramework("dynamic-certificate")

	BeforeEach(func() {
		err := enableDynamicCertificates(f.IngressController.Namespace, f.KubeClientSet)
		Expect(err).NotTo(HaveOccurred())

		err = f.NewEchoDeploymentWithReplicas(1)
		Expect(err).NotTo(HaveOccurred())

		host := "foo.com"
		ing, err := ensureIngress(f, host)
		Expect(err).NotTo(HaveOccurred())
		Expect(ing).NotTo(BeNil())

		// give some time for Lua to sync the backend
		time.Sleep(5 * time.Second)

		resp, _, errs := gorequest.New().
			Get(f.IngressController.HTTPURL).
			Set("Host", host).
			End()
		Expect(len(errs)).Should(BeNumerically("==", 0))
		Expect(resp.StatusCode).Should(Equal(http.StatusOK))

		Expect(err).ToNot(HaveOccurred())
	})

	Context("when only servers change", func() {
		It("should handle SSL certificate only changes", func() {
			ingress, err := f.KubeClientSet.ExtensionsV1beta1().Ingresses(f.IngressController.Namespace).Get("foo.com", metav1.GetOptions{})
			Expect(err).ToNot(HaveOccurred())

			ingress.Spec.TLS = []extensions.IngressTLS{
				{
					Hosts:      []string{"foo.com"},
					SecretName: "foo.com",
				},
			}

			_, err = framework.CreateIngressTLSSecret(f.KubeClientSet,
				ingress.Spec.TLS[0].Hosts,
				ingress.Spec.TLS[0].SecretName,
				ingress.Namespace)
			Expect(err).ToNot(HaveOccurred())

			resp, _, errs := gorequest.New().
				Get(fmt.Sprintf("%s?id=certificate_only_changes", f.IngressController.HTTPURL)).
				Set("Host", "foo.com").
				End()
			Expect(len(errs)).Should(BeNumerically("==", 0))
			Expect(resp.StatusCode).Should(Equal(http.StatusOK))

			_, err = f.KubeClientSet.ExtensionsV1beta1().Ingresses(f.IngressController.Namespace).Update(ingress)
			Expect(err).ToNot(HaveOccurred())
			time.Sleep(5 * time.Second)

			log, err := f.NginxLogs()
			Expect(err).ToNot(HaveOccurred())
			Expect(log).ToNot(BeEmpty())

			index := strings.Index(log, "id=certificate_only_changes")
			restOfLogs := log[index:]

			By("POSTing new certificates to Lua endpoint")
			Expect(restOfLogs).To(ContainSubstring(logDynamicConfigSuccess))
			Expect(restOfLogs).ToNot(ContainSubstring(logDynamicConfigFailure))

			By("skipping Nginx reload")
			Expect(restOfLogs).ToNot(ContainSubstring(logRequireBackendReload))
			Expect(restOfLogs).ToNot(ContainSubstring(logBackendReloadSuccess))
			Expect(restOfLogs).To(ContainSubstring(logSkipBackendReload))
			Expect(restOfLogs).ToNot(ContainSubstring(logInitialConfigSync))
		})

		It("should be able to update SSL certificate even when the update POST size(request body) > size(client_body_buffer_size)", func() {
			// Update client-body-buffer-size to 1 byte
			err := f.UpdateNginxConfigMapData("client-body-buffer-size", "1")
			Expect(err).NotTo(HaveOccurred())

			ingress, err := f.KubeClientSet.ExtensionsV1beta1().Ingresses(f.IngressController.Namespace).Get("foo.com", metav1.GetOptions{})
			Expect(err).ToNot(HaveOccurred())

			ingress.Spec.TLS = []extensions.IngressTLS{
				{
					Hosts:      []string{"foo.com"},
					SecretName: "foo.com",
				},
			}

			_, err = framework.CreateIngressTLSSecret(f.KubeClientSet,
				ingress.Spec.TLS[0].Hosts,
				ingress.Spec.TLS[0].SecretName,
				ingress.Namespace)
			Expect(err).ToNot(HaveOccurred())

			_, err = f.KubeClientSet.ExtensionsV1beta1().Ingresses(f.IngressController.Namespace).Update(ingress)
			Expect(err).ToNot(HaveOccurred())
			time.Sleep(5 * time.Second)

			resp, _, errs := gorequest.New().
				Get(f.IngressController.HTTPURL).
				Set("Host", "foo.com").
				End()
			Expect(len(errs)).Should(BeNumerically("==", 0))
			Expect(resp.StatusCode).Should(Equal(http.StatusOK))

			log, err := f.NginxLogs()
			Expect(err).ToNot(HaveOccurred())
			Expect(log).ToNot(BeEmpty())
			index := strings.Index(log, "POST /configuration/servers HTTP/1.1")
			restOfLogs := log[index:]

			Expect(err).ToNot(HaveOccurred())
			Expect(log).ToNot(BeEmpty())

			By("POSTing new servers to Lua endpoint")
			Expect(restOfLogs).ToNot(ContainSubstring("dynamic-configuration: unable to read valid request body"))
		})
	})
})

func enableDynamicCertificates(namespace string, kubeClientSet kubernetes.Interface) error {
	return framework.UpdateDeployment(kubeClientSet, namespace, "nginx-ingress-controller", 1,
		func(deployment *appsv1beta1.Deployment) error {
			args := deployment.Spec.Template.Spec.Containers[0].Args
			args = append(args, "--enable-dynamic-configuration")
			args = append(args, "--enable-dynamic-certificates")
			args = append(args, "--enable-ssl-chain-completion=false")
			deployment.Spec.Template.Spec.Containers[0].Args = args
			_, err := kubeClientSet.AppsV1beta1().Deployments(namespace).Update(deployment)
			if err != nil {
				return err
			}

			return nil
		})
}
