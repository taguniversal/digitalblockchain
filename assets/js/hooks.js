let Hooks = {}

Hooks.ClipboardCopy = {
    mounted() {

      const initialInnerHTML = this.el.innerHTML;
      const { content } = this.el.dataset;
  
      this.el.addEventListener("click", () => {
   
        navigator.clipboard.writeText(content);
  
        this.el.innerHTML = "Copied!";
  
        setTimeout(() => {
          this.el.innerHTML = initialInnerHTML;
        }, 2000);
      });
    },
  }

  Hooks.ClipboardPaste = {
    mounted() {
     
      this.el.addEventListener("click", () => {
        navigator.clipboard.readText().then((text) => {
          // Assuming the element has a data-content attribute where you want to paste the text
          this.pushEvent("block-pasted", {pastedText: text})
          
          // You can add additional logic here if needed
          // For example, store the text in a hidden input for further processing
        }).catch(err => {
          console.error('Failed to read clipboard contents: ', err);
        });
      });
    }
  }
  
    

export default Hooks;